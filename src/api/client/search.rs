use std::collections::BTreeMap;

use axum::extract::State;
use ruma::{
	api::client::{
		error::ErrorKind,
		search::search_events::{
			self,
			v3::{EventContextResult, ResultCategories, ResultRoomEvents, SearchResult},
		},
	},
	events::AnyStateEvent,
	serde::Raw,
	uint, OwnedRoomId,
};
use tracing::debug;

use crate::{Error, Result, Ruma};

/// # `POST /_matrix/client/r0/search`
///
/// Searches rooms for messages.
///
/// - Only works if the user is currently joined to the room (TODO: Respect
///   history visibility)
pub(crate) async fn search_events_route(
	State(services): State<crate::State>, body: Ruma<search_events::v3::Request>,
) -> Result<search_events::v3::Response> {
	let sender_user = body.sender_user.as_ref().expect("user is authenticated");

	let search_criteria = body.search_categories.room_events.as_ref().unwrap();
	let filter = &search_criteria.filter;
	let include_state = &search_criteria.include_state;

	let room_ids = filter.rooms.clone().unwrap_or_else(|| {
		services
			.rooms
			.state_cache
			.rooms_joined(sender_user)
			.filter_map(Result::ok)
			.collect()
	});

	// Use limit or else 10, with maximum 100
	let limit: usize = filter
		.limit
		.unwrap_or_else(|| uint!(10))
		.try_into()
		.unwrap_or(10)
		.min(100);

	let mut room_states: BTreeMap<OwnedRoomId, Vec<Raw<AnyStateEvent>>> = BTreeMap::new();

	if include_state.is_some_and(|include_state| include_state) {
		for room_id in &room_ids {
			if !services.rooms.state_cache.is_joined(sender_user, room_id)? {
				return Err(Error::BadRequest(
					ErrorKind::forbidden(),
					"You don't have permission to view this room.",
				));
			}

			// check if sender_user can see state events
			if services
				.rooms
				.state_accessor
				.user_can_see_state_events(sender_user, room_id)?
			{
				let room_state = services
					.rooms
					.state_accessor
					.room_state_full(room_id)
					.await?
					.values()
					.map(|pdu| pdu.to_state_event())
					.collect::<Vec<_>>();

				debug!("Room state: {:?}", room_state);

				room_states.insert(room_id.clone(), room_state);
			} else {
				return Err(Error::BadRequest(
					ErrorKind::forbidden(),
					"You don't have permission to view this room.",
				));
			}
		}
	}

	let mut searches = Vec::new();

	for room_id in &room_ids {
		if !services.rooms.state_cache.is_joined(sender_user, room_id)? {
			return Err(Error::BadRequest(
				ErrorKind::forbidden(),
				"You don't have permission to view this room.",
			));
		}

		if let Some(search) = services
			.rooms
			.search
			.search_pdus(room_id, &search_criteria.search_term)?
		{
			searches.push(search.0.peekable());
		}
	}

	let skip: usize = match body.next_batch.as_ref().map(|s| s.parse()) {
		Some(Ok(s)) => s,
		Some(Err(_)) => return Err(Error::BadRequest(ErrorKind::InvalidParam, "Invalid next_batch token.")),
		None => 0, // Default to the start
	};

	let mut results = Vec::new();
	let next_batch = skip.saturating_add(limit);

	for _ in 0..next_batch {
		if let Some(s) = searches
			.iter_mut()
			.map(|s| (s.peek().cloned(), s))
			.max_by_key(|(peek, _)| peek.clone())
			.and_then(|(_, i)| i.next())
		{
			results.push(s);
		}
	}

	let results: Vec<_> = results
		.iter()
		.skip(skip)
		.filter_map(|result| {
			services
				.rooms
				.timeline
				.get_pdu_from_id(result)
				.ok()?
				.filter(|pdu| {
					!pdu.is_redacted()
						&& services
							.rooms
							.state_accessor
							.user_can_see_event(sender_user, &pdu.room_id, &pdu.event_id)
							.unwrap_or(false)
				})
				.map(|pdu| pdu.to_room_event())
		})
		.map(|result| {
			Ok::<_, Error>(SearchResult {
				context: EventContextResult {
					end: None,
					events_after: Vec::new(),
					events_before: Vec::new(),
					profile_info: BTreeMap::new(),
					start: None,
				},
				rank: None,
				result: Some(result),
			})
		})
		.filter_map(Result::ok)
		.take(limit)
		.collect();

	let more_unloaded_results = searches.iter_mut().any(|s| s.peek().is_some());
	let next_batch = more_unloaded_results.then(|| next_batch.to_string());

	Ok(search_events::v3::Response::new(ResultCategories {
		room_events: ResultRoomEvents {
			count: Some(results.len().try_into().unwrap_or_else(|_| uint!(0))),
			groups: BTreeMap::new(), // TODO
			next_batch,
			results,
			state: room_states,
			highlights: search_criteria
				.search_term
				.split_terminator(|c: char| !c.is_alphanumeric())
				.map(str::to_lowercase)
				.collect(),
		},
	}))
}

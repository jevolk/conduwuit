use axum::extract::State;
use conduwuit::Err;
use ruma::api::client::typing::create_typing_event;

use crate::{utils, Result, Ruma};

/// # `PUT /_matrix/client/r0/rooms/{roomId}/typing/{userId}`
///
/// Sets the typing state of the sender user.
pub(crate) async fn create_typing_event_route(
	State(services): State<crate::State>,
	body: Ruma<create_typing_event::v3::Request>,
) -> Result<create_typing_event::v3::Response> {
	use create_typing_event::v3::Typing;
	let sender_user = body.sender_user();

	if sender_user != body.user_id && body.appservice_info.is_none() {
		return Err!(Request(Forbidden("You cannot update typing status of other users.")));
	}

	if !services
		.rooms
		.state_cache
		.is_joined(sender_user, &body.room_id)
		.await
	{
		return Err!(Request(Forbidden("You are not in this room.")));
	}

	if let Typing::Yes(duration) = body.state {
		let duration = utils::clamp(
			duration.as_millis().try_into().unwrap_or(u64::MAX),
			services
				.globals
				.config
				.typing_client_timeout_min_s
				.checked_mul(1000)
				.unwrap(),
			services
				.globals
				.config
				.typing_client_timeout_max_s
				.checked_mul(1000)
				.unwrap(),
		);
		services
			.rooms
			.typing
			.typing_add(
				sender_user,
				&body.room_id,
				utils::millis_since_unix_epoch()
					.checked_add(duration)
					.expect("user typing timeout should not get this high"),
			)
			.await?;
	} else {
		services
			.rooms
			.typing
			.typing_remove(sender_user, &body.room_id)
			.await?;
	}

	// ping presence
	if services.globals.allow_local_presence() {
		services
			.presence
			.ping_presence(&body.user_id, &ruma::presence::PresenceState::Online)
			.await?;
	}

	Ok(create_typing_event::v3::Response {})
}

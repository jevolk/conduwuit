use std::{mem::size_of, sync::Arc};

use conduit::{utils, Error, PduCount, PduEvent, Result};
use database::Map;
use ruma::{EventId, RoomId, UserId};

use crate::{rooms, Dep};

pub(super) struct Data {
	tofrom_relation: Arc<Map>,
	referencedevents: Arc<Map>,
	softfailedeventids: Arc<Map>,
	services: Services,
}

struct Services {
	timeline: Dep<rooms::timeline::Service>,
}

type PdusIterItem = Result<(PduCount, PduEvent)>;
type PdusIterator<'a> = Box<dyn Iterator<Item = PdusIterItem> + 'a>;

impl Data {
	pub(super) fn new(args: &crate::Args<'_>) -> Self {
		let db = &args.db;
		Self {
			tofrom_relation: db["tofrom_relation"].clone(),
			referencedevents: db["referencedevents"].clone(),
			softfailedeventids: db["softfailedeventids"].clone(),
			services: Services {
				timeline: args.depend::<rooms::timeline::Service>("rooms::timeline"),
			},
		}
	}

	pub(super) fn add_relation(&self, from: u64, to: u64) -> Result<()> {
		let mut key = to.to_be_bytes().to_vec();
		key.extend_from_slice(&from.to_be_bytes());
		self.tofrom_relation.insert(&key, &[])?;
		Ok(())
	}

	pub(super) fn relations_until<'a>(
		&'a self, user_id: &'a UserId, shortroomid: u64, target: u64, until: PduCount,
	) -> Result<PdusIterator<'a>> {
		let prefix = target.to_be_bytes().to_vec();
		let mut current = prefix.clone();

		let count_raw = match until {
			PduCount::Normal(x) => x.saturating_sub(1),
			PduCount::Backfilled(x) => {
				current.extend_from_slice(&0_u64.to_be_bytes());
				u64::MAX.saturating_sub(x).saturating_sub(1)
			},
		};
		current.extend_from_slice(&count_raw.to_be_bytes());

		Ok(Box::new(
			self.tofrom_relation
				.iter_from(&current, true)
				.take_while(move |(k, _)| k.starts_with(&prefix))
				.map(move |(tofrom, _data)| {
					let from = utils::u64_from_bytes(&tofrom[(size_of::<u64>())..])
						.map_err(|_| Error::bad_database("Invalid count in tofrom_relation."))?;

					let mut pduid = shortroomid.to_be_bytes().to_vec();
					pduid.extend_from_slice(&from.to_be_bytes());

					let mut pdu = self
						.services
						.timeline
						.get_pdu_from_id(&pduid)?
						.ok_or_else(|| Error::bad_database("Pdu in tofrom_relation is invalid."))?;
					if pdu.sender != user_id {
						pdu.remove_transaction_id()?;
					}
					Ok((PduCount::Normal(from), pdu))
				}),
		))
	}

	pub(super) fn mark_as_referenced(&self, room_id: &RoomId, event_ids: &[Arc<EventId>]) -> Result<()> {
		for prev in event_ids {
			let mut key = room_id.as_bytes().to_vec();
			key.extend_from_slice(prev.as_bytes());
			self.referencedevents.insert(&key, &[])?;
		}

		Ok(())
	}

	pub(super) fn is_event_referenced(&self, room_id: &RoomId, event_id: &EventId) -> Result<bool> {
		let mut key = room_id.as_bytes().to_vec();
		key.extend_from_slice(event_id.as_bytes());
		Ok(self.referencedevents.get(&key)?.is_some())
	}

	pub(super) fn mark_event_soft_failed(&self, event_id: &EventId) -> Result<()> {
		self.softfailedeventids.insert(event_id.as_bytes(), &[])
	}

	pub(super) fn is_event_soft_failed(&self, event_id: &EventId) -> Result<bool> {
		self.softfailedeventids
			.get(event_id.as_bytes())
			.map(|o| o.is_some())
	}
}

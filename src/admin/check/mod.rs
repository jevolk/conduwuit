mod commands;

use clap::Subcommand;
use conduit::Result;
use ruma::events::room::message::RoomMessageEventContent;

use self::commands::*;

#[cfg_attr(test, derive(Debug))]
#[derive(Subcommand)]
pub(super) enum CheckCommand {
	AllUsers,
}

pub(super) async fn process(command: CheckCommand, body: Vec<&str>) -> Result<RoomMessageEventContent> {
	Ok(match command {
		CheckCommand::AllUsers => check_all_users(body).await?,
	})
}

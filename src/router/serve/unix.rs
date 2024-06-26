#![cfg(unix)]

use std::{
	net::{self, IpAddr, Ipv4Addr},
	path::Path,
	sync::Arc,
};

use axum::{
	extract::{connect_info::IntoMakeServiceWithConnectInfo, Request},
	Router,
};
use conduit::{debug_error, trace, utils, Error, Result, Server};
use hyper::{body::Incoming, service::service_fn};
use hyper_util::{
	rt::{TokioExecutor, TokioIo},
	server,
};
use tokio::{
	fs,
	net::{unix::SocketAddr, UnixListener, UnixStream},
	sync::broadcast::{self},
	task::JoinSet,
};
use tower::{Service, ServiceExt};
use tracing::{debug, info, warn};
use utils::unwrap_infallible;

type MakeService = IntoMakeServiceWithConnectInfo<Router, net::SocketAddr>;

static NULL_ADDR: net::SocketAddr = net::SocketAddr::new(IpAddr::V4(Ipv4Addr::new(0, 0, 0, 0)), 0);

#[tracing::instrument(skip_all)]
pub(super) async fn serve(server: &Arc<Server>, app: Router, mut shutdown: broadcast::Receiver<()>) -> Result<()> {
	let mut tasks = JoinSet::<()>::new();
	let executor = TokioExecutor::new();
	let app = app.into_make_service_with_connect_info::<net::SocketAddr>();
	let builder = server::conn::auto::Builder::new(executor);
	let listener = init(server).await?;
	loop {
		let app = app.clone();
		let builder = builder.clone();
		tokio::select! {
			_sig = shutdown.recv() => break,
			conn = listener.accept() => match conn {
				Ok(conn) => accept(server, &listener, &mut tasks, app, builder, conn).await,
				Err(err) => debug_error!(?listener, "accept error: {err}"),
			},
		}
	}

	fini(listener, tasks).await;

	Ok(())
}

#[allow(clippy::let_underscore_must_use)]
async fn accept(
	server: &Arc<Server>, listener: &UnixListener, tasks: &mut JoinSet<()>, mut app: MakeService,
	builder: server::conn::auto::Builder<TokioExecutor>, conn: (UnixStream, SocketAddr),
) {
	let (socket, remote) = conn;
	let socket = TokioIo::new(socket);
	trace!(?listener, ?socket, ?remote, "accepted");

	let called = unwrap_infallible(app.call(NULL_ADDR).await);
	let handler = service_fn(move |req: Request<Incoming>| called.clone().oneshot(req));

	let task = async move {
		// bug on darwin causes all results to be errors. do not unwrap this
		_ = builder.serve_connection(socket, handler).await;
	};

	_ = tasks.spawn_on(task, server.runtime());
	while tasks.try_join_next().is_some() {}
}

async fn init(server: &Arc<Server>) -> Result<UnixListener> {
	use std::os::unix::fs::PermissionsExt;

	let config = &server.config;
	let path = config
		.unix_socket_path
		.as_ref()
		.expect("failed to extract configured unix socket path");

	if path.exists() {
		warn!("Removing existing UNIX socket {:#?} (unclean shutdown?)...", path.display());
		fs::remove_file(&path)
			.await
			.map_err(|e| warn!("Failed to remove existing UNIX socket: {e}"))
			.unwrap();
	}

	let dir = path.parent().unwrap_or_else(|| Path::new("/"));
	if let Err(e) = fs::create_dir_all(dir).await {
		return Err(Error::Err(format!("Failed to create {dir:?} for socket {path:?}: {e}")));
	}

	let listener = UnixListener::bind(path);
	if let Err(e) = listener {
		return Err(Error::Err(format!("Failed to bind listener {path:?}: {e}")));
	}

	let socket_perms = config.unix_socket_perms.to_string();
	let octal_perms = u32::from_str_radix(&socket_perms, 8).expect("failed to convert octal permissions");
	let perms = std::fs::Permissions::from_mode(octal_perms);
	if let Err(e) = fs::set_permissions(&path, perms).await {
		return Err(Error::Err(format!("Failed to set socket {path:?} permissions: {e}")));
	}

	info!("Listening at {:?}", path);

	Ok(listener.unwrap())
}

async fn fini(listener: UnixListener, mut tasks: JoinSet<()>) {
	let local = listener.local_addr();

	drop(listener);
	tasks.shutdown().await;

	if let Ok(local) = local {
		if let Some(path) = local.as_pathname() {
			debug!(?path, "Removing unix socket file.");
			if let Err(e) = fs::remove_file(path).await {
				warn!(?path, "Failed to remove UNIX socket file: {e}");
			}
		}
	}
}

use futures::{stream::FuturesUnordered, StreamExt};
use moq_transport::{
    serve::{ServeError, TrackReader, TracksReader},
    session::{Publisher, SessionError, Subscribed},
};

use scopeguard::guard;

use crate::{Locals, RemotesConsumer};

#[derive(Clone)]
pub struct Producer {
    remote: Publisher,
    locals: Locals,
    remotes: Option<RemotesConsumer>,
}

impl Producer {
    pub fn new(remote: Publisher, locals: Locals, remotes: Option<RemotesConsumer>) -> Self {
        Self {
            remote,
            locals,
            remotes,
        }
    }

    pub async fn announce(&mut self, tracks: TracksReader) -> Result<(), SessionError> {
        self.remote.announce(tracks).await
    }

    pub async fn run(mut self) -> Result<(), SessionError> {
        let mut tasks = FuturesUnordered::new();

        loop {
            tokio::select! {
                Some(subscribe) = self.remote.subscribed() => {
                    let this = self.clone();

                    tasks.push(async move {
                        let info = subscribe.clone();
                        log::info!("serving subscribe: {:?}", info);

                        if let Err(err) = this.serve(subscribe).await {
                            log::warn!("failed serving subscribe: {:?}, error: {}", info, err)
                        }
                    })
                },
                _= tasks.next(), if !tasks.is_empty() => {},
                else => return Ok(()),
            };
        }
    }

    async fn serve(self, subscribe: Subscribed) -> Result<(), anyhow::Error> {
        moq_metrics::increment_active_subscribed_tracks();
        let _subscriber_guard = guard((), |_| {
            moq_metrics::decrement_active_subscribed_tracks();
        });
        let mut track_to_serve: Option<TrackReader> = None;

        if let Some(mut local) = self.locals.route(&subscribe.namespace) {
            if let Some(track_reader) = local.subscribe(&subscribe.name) {
                log::info!("serving from local: {:?}", track_reader.info);
                track_to_serve = Some(track_reader);
            }
        }

        if track_to_serve.is_none() {
            if let Some(remotes) = &self.remotes {
                if let Some(remote) = remotes.route(&subscribe.namespace).await? {
                    if let Some(remote_track) =
                        remote.subscribe(subscribe.namespace.clone(), subscribe.name.clone())?
                    {
                        log::info!(
                            "serving from remote: {:?} {:?}",
                            remote.info,
                            remote_track.info
                        );

                        track_to_serve = Some(remote_track.reader);
                    }
                }
            }
        }

        if let Some(track) = track_to_serve {
            return Ok(subscribe.serve(track).await?);
        }

        Err(ServeError::NotFound.into())
    }
}

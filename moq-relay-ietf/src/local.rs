use std::collections::hash_map;
use std::collections::HashMap;

use std::sync::{Arc, Mutex};

use moq_metrics::RelayMetrics;

use moq_transport::{
    coding::TrackNamespace,
    serve::{ServeError, TracksReader},
};

#[derive(Clone)]
pub struct Locals {
    lookup: Arc<Mutex<HashMap<TrackNamespace, TracksReader>>>,
    metrics: RelayMetrics,
}

impl Locals {
    pub fn new(metrics: RelayMetrics) -> Self {
        Self {
            lookup: Default::default(),
            metrics
        }
    }

    pub async fn register(&mut self, tracks: TracksReader) -> anyhow::Result<Registration> {
        let namespace = tracks.namespace.clone();
        match self.lookup.lock().unwrap().entry(namespace.clone()) {
            hash_map::Entry::Vacant(entry) => {
                entry.insert(tracks);

                self.metrics.announced_tracks_total.inc();
                self.metrics.announced_tracks_current.inc();
            },
            hash_map::Entry::Occupied(_) => return Err(ServeError::Duplicate.into()),
        };

        let registration = Registration {
            locals: self.clone(),
            namespace,
        };

        Ok(registration)
    }

    pub fn route(&self, namespace: &TrackNamespace) -> Option<TracksReader> {
        self.lookup.lock().unwrap().get(namespace).cloned()
    }
}

pub struct Registration {
    locals: Locals,
    namespace: TrackNamespace,
}

impl Drop for Registration {
    fn drop(&mut self) {
        let mut lookup= self.locals.lookup.lock().unwrap();
        if lookup.remove(&self.namespace).is_some() {
             self.locals.metrics.announced_tracks_current.dec();
        }
    }
}

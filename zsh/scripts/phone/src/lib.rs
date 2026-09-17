//! Library surface for the phone lab CLI (injectable runner + domain ops).

pub mod adb;
pub mod config;
pub mod control;
pub mod error;
pub mod harden;
pub mod json_out;
pub mod runner;
pub mod screen;
pub mod transport;
pub mod wan;

pub use error::{Error, Result};

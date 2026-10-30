//! Library surface for the phone lab CLI (injectable runner + domain ops).

pub mod adb;
pub mod agent;
pub mod config;
pub mod control;
pub mod doctor;
pub mod error;
pub mod harden;
pub mod json_out;
pub mod persist;
pub mod runner;
pub mod screen;
pub mod ssh_ops;
pub mod termux_guard;
pub mod transport;
pub mod wan;

pub use error::{Error, Result};

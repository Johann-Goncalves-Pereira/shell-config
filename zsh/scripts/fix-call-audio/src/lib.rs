//! Library surface for the fix-call-audio lab CLI.

pub mod agent;
pub mod devices;
pub mod enforce;
pub mod error;
pub mod hfp;
pub mod hide;
pub mod json_out;
pub mod offender;
pub mod runner;
pub mod session;

pub use error::{Error, Result};

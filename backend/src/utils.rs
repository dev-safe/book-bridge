use chrono::{DateTime, Utc};
use rand::RngExt;
use sha2::{Digest, Sha256};

pub fn hash_sha256(input: &[u8]) -> Vec<u8> {
    let mut hasher = Sha256::new();
    hasher.update(input);
    hasher.finalize().to_vec()
}

pub fn generate_random_bytes(len: usize) -> Vec<u8> {
    let mut bytes = vec![0u8; len];
    rand::rng().fill(&mut bytes[..]);
    bytes
}

pub fn generate_random_token() -> String {
    let bytes = generate_random_bytes(32);
    // Simple hex string without extra hex crate if not needed or with fmt
    bytes.iter().map(|b| format!("{b:02x}")).collect()
}

pub fn dt_to_proto(dt: DateTime<Utc>) -> buffa_types::google::protobuf::Timestamp {
    buffa_types::google::protobuf::Timestamp {
        seconds: dt.timestamp(),
        nanos: dt.timestamp_subsec_nanos() as i32,
        ..Default::default()
    }
}

pub fn opt_dt_to_proto(
    opt: Option<DateTime<Utc>>,
) -> buffa::MessageField<
    buffa_types::google::protobuf::Timestamp,
    buffa::Inline<buffa_types::google::protobuf::Timestamp>,
> {
    opt.map(dt_to_proto).into()
}


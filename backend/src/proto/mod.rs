#[allow(dead_code, unused_imports, unused_qualifications)]
pub mod buf {
    #[allow(dead_code, unused_imports, unused_qualifications)]
    pub mod bookbridge {
        #[allow(dead_code, unused_imports, unused_qualifications)]
        pub mod v1 {
            include!("buf/bookbridge.v1.rs");
        }
    }
}

#[allow(dead_code, unused_imports, unused_qualifications)]
pub mod svc {
    #[allow(dead_code, unused_imports, unused_qualifications)]
    pub mod bookbridge {
        #[allow(dead_code, unused_imports, unused_qualifications)]
        pub mod v1 {
            include!("svc/bookbridge.v1.rs");
        }
    }
}

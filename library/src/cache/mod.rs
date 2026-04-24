mod disk_io;
mod patch_manager;
mod signing;
pub mod updater_state;

pub use patch_manager::AssetsInstall;
pub use signing::hash_file;
pub use updater_state::UpdaterState;

/// The public interface for talking about patches to the Cache.
#[derive(PartialEq, Eq, Debug, Clone)]
pub struct PatchInfo {
    pub path: std::path::PathBuf,
    pub number: usize,
    /// Path to the extracted Flutter assets directory for this patch,
    /// or `None` if the patch has no asset delta. Engine reads this
    /// via [`crate::c_api::shorebird_next_boot_assets_dir`] and uses
    /// it as a patch-first override ahead of the release bundle.
    pub assets_dir: Option<std::path::PathBuf>,
}

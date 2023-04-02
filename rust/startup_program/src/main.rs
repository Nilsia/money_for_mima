/* use auto_launch

*/fn main() {
    println!("Hello, world!");
} /*

fn set_program_startup() {
    let auto = AutoLaunchBuilder::new()
        .set_app_name("startup_money_for_mima")
        .set_app_path("/path/to/the-app")
        .set_use_launch_agent(true)
        .set_args(&["--minimized"])
        .build()
        .unwrap();

    auto.enable().is_ok();
    auto.is_enabled().unwrap();

    auto.disable().is_ok();
    auto.is_enabled().unwrap();
} */
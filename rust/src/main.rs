use chrono;
use dirs;
use std::fs;
use std::io;
use std::io::prelude::*;
use std::path::Path;
use std::process::exit;

fn pause() {
    let mut stdin = io::stdin();
    let mut stdout = io::stdout();

    // We want the cursor to stay at the end of the line, so we print without a newline and flush manually.
    writeln!(stdout, "Stiskni jakoukoliv klávesu pro ukončení programu.")
        .expect("Could not write out message");
    stdout.flush().expect("Couldn't flush stdout");

    // Read a single byte and discard
    let _ = stdin
        .read(&mut [0u8])
        .expect("Couldn't read byte from stdin");
}

fn is_folder_empty<P: AsRef<Path>>(path: P) -> io::Result<bool> {
    Ok(fs::read_dir(path)?.take(1).count() == 0)
}

fn main() {
    let today_date = chrono::Utc::now().format("%Y-%m-%d");

    // Declare directories
    let source_dir = "/run/user/1000/gvfs/gphoto2:host=NIKON_NIKON_DSC_COOLPIX_S3300-PTP_000047028642/DCIM/100NIKON";
    let target_dir = match dirs::picture_dir() {
        Some(value) => value,
        None => {
            eprintln!("Chyba: Cílová složka nelze nalézt");
            pause();
            exit(1);
        }
    };

    let source_dir = Path::new(&source_dir);
    let target_dir = Path::new(&target_dir);
    match source_dir.exists() && source_dir.is_dir() {
        true => {}
        false => {
            eprintln!("Chyba: zdrojová složka neexistuje");
            pause();
            exit(1);
        }
    }

    match target_dir.exists() && source_dir.is_dir() {
        true => {}
        false => {
            eprintln!("Chyba: cílová složka neexistuje");
            pause();
            exit(1);
        }
    }

    match is_folder_empty(&source_dir) {
        Ok(true) => exit(0),
        Ok(false) => {}
        Err(err) => {
            eprintln!(
                "Chyba: Při kontrole zdrojové složky se stala chyba, {}",
                err
            );
            pause();
            exit(1);
        }
    }

    let mut target_dir = target_dir.join(today_date.to_string());

    match target_dir.exists() && target_dir.is_dir() {
        true => {}
        false => {
            fs::create_dir(&target_dir).expect("Could not create directory");
        }
    };

    let mut dirs = vec![];

    for entry in fs::read_dir(&target_dir).expect("This directory should exist") {
        let entry = entry.expect("Something inside directory couldn't be read");
        let path = entry.path();
        let filename = entry.file_name();
        if path.is_dir()
            && filename
                .to_str()
                .expect("Could not convert OsString to &str")
                .chars()
                .all(char::is_numeric)
        {
            &mut dirs.push(filename);
        }
    }

    let mut folder_iter: i32;
    if let Some(max) = dirs.iter().max() {
        folder_iter = max
            .to_str()
            .expect("Not able to parse &OsString to &str")
            .parse()
            .expect("Not able to parse string into integer");
    } else {
        folder_iter = 1;
    }

    let test_target_dir = Path::new(&target_dir).join(format!("{:02}", folder_iter));
    match test_target_dir.exists() && test_target_dir.is_dir() {
        true => match is_folder_empty(&test_target_dir) {
            Ok(true) => target_dir = test_target_dir,
            Ok(false) => {
                folder_iter += 1;
                target_dir = Path::new(&target_dir).join(format!("{:02}", folder_iter));
                fs::create_dir(&target_dir).expect("Could not create directory");
            }
            Err(err) => {
                eprintln!("Chyba: Při kontrole cílové složky se stala chyba, {}", err);
                pause();
                exit(1);
            }
        },
        false => {
            target_dir = test_target_dir;
            fs::create_dir(&target_dir).expect("Could not create directory");
        }
    };

    for entry in fs::read_dir(&source_dir).expect("This directory should exist") {
        let entry = entry.expect("Something inside directory couldn't be read");
        let path = entry.path();
        if path.is_file() {
            let filename = entry.file_name();
            fs::copy(&path, Path::new(&target_dir).join(filename))
                .expect("Some file couldn't be copied");
            fs::remove_file(&path).expect("Unable to delete file");
        }
    }
}

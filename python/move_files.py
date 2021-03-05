#!/usr/bin/env python3
import subprocess
import sys
from pathlib import Path
import shutil
import os
from datetime import date

today = date.today()
bash_command = 'xdg-user-dir PICTURES'
source_dir = '/run/user/1000/gvfs/gphoto2:host=NIKON_NIKON_DSC_COOLPIX_S3300-PTP_000047028642/DCIM/100NIKON'

proc = subprocess.run(bash_command.split(),
                      stdin=subprocess.PIPE, stdout=subprocess.PIPE)

if (proc.stderr != None):
    sys.exit(f'Error: {proc.stderr}')

target_dir = proc.stdout.decode('utf-8').strip('\r\n')

if not Path(target_dir).exists():
    print(f'Chyba: Složka "{target_dir}" neexistuje')
    input('Stiskni jakoukoliv klávesu pro ukončení programu')
    sys.exit(1)

if not Path(source_dir).exists():
    print(f'Chyba: Složka "{source_dir}" neexistuje')
    input('Stiskni jakoukoliv klávesu pro ukončení programu')
    sys.exit(1)

files = os.listdir(source_dir)
if len(files) == 0:
    sys.exit(0)

target_dir = f'{target_dir}/{today}'
Path(target_dir).mkdir(parents=True, exist_ok=True)

dirs = []
for f in os.listdir(target_dir):
    fp = f'{target_dir}/{f}'
    if Path(fp).is_dir() & f.isdigit():
        if len(os.listdir(fp)) != 0:
            dirs.append(f)

if len(dirs) != 0:
    sub_dir = str((int(max(dirs)) + 1)).zfill(2)
else:
    sub_dir = '1'.zfill(2)

target_dir = f'{target_dir}/{sub_dir}'
Path(target_dir).mkdir(parents=True, exist_ok=True)

files = []
for f in os.listdir(source_dir):
    if Path(source_dir).joinpath(f).is_file():
        files.append(f)

for f in files:
    shutil.move(str(Path(source_dir).joinpath(f)), target_dir)

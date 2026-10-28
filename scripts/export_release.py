"""Copy only public project files, excluding machine state and reading history."""
import argparse
import shutil
from pathlib import Path

FILES = ['README.md', 'LICENSE', 'CONTRIBUTING.md', '.gitignore']
DIRECTORIES = ['lua', 'plugin', 'scripts', 'tests', 'doc', 'integration', 'books', '.github']


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('destination', type=Path)
    args = parser.parse_args()
    source = Path(__file__).resolve().parents[1]
    destination = args.destination.resolve()
    if destination.exists():
        raise SystemExit('Destination must not already exist')
    if destination == source or source in destination.parents:
        raise SystemExit('Export outside the source directory')
    destination.mkdir(parents=True)
    for name in FILES:
        shutil.copy2(source / name, destination / name)
    for name in DIRECTORIES:
        shutil.copytree(source / name, destination / name,
                        ignore=shutil.ignore_patterns('__pycache__', '*.pyc', '*.log', 'tags'))
    print(destination)


if __name__ == '__main__':
    main()

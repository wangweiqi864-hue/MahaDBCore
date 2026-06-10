# MahaDBCore

`MahaDBCore` is a lightweight SQLite wrapper extracted from `MHDBManager` for private pod distribution.

## Structure

- `MahaDBCore/Classes/MahaDBManager.swift`: public database manager entrypoint
- `MahaDBCore/Classes/MahaDBModel.swift`: base model and CRUD helpers
- `MahaDBCore/Classes/MahaDBColumn.swift`: internal column metadata model
- `MahaDBCore.podspec`: pod definition for private distribution

## Current Behavior

- Keeps the current SQLite table creation and auto-column migration behavior
- Exposes renamed public database manager and model base types
- Depends on `SQLite.swift`, `HandyJSON`, and `MahaLogCore`

## Installation

This repository is prepared for private pod distribution through:

- Pod source repo: `https://github.com/wangweiqi864-hue/MaHaSpecs.git`
- Library repo: `https://github.com/wangweiqi864-hue/MahaDBCore.git`

## Notes

- Prepared from `Maha_/LocalPods/MHDBManager`
- The original app integration is intentionally untouched at this stage

## License

Declared as `MIT` in the podspec.

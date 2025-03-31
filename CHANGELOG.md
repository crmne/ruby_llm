# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed

- Fixed bug where user messages were not saved to the database when using `with_tools`. The issue occurred because the method chain returned a pure Ruby object that lost the ActiveRecord connection.

## [1.0.1] - 2024-02-28

### Added

Initial release of the Ruby LLM gem.
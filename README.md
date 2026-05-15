<p align="center">
  <img src="Assets/Icons/readme-icon.png" width="112" height="112" alt="Scout icon">
</p>

<h1 align="center">Scout</h1>

<p align="center">
  A small macOS app for finding heavy files, caches, and build artifacts.
</p>

<br>

## Install

Download `Scout.dmg`, open it, then drag Scout to Applications.

<br>

## What It Does

Scout scans your home folder, or any folder you choose, and shows the heaviest items it finds. It focuses on files, caches, build outputs, toolchains, models, and large folders that are worth reviewing.

The app does not permanently delete anything. When you choose to remove an item, it asks first, then moves it to macOS Trash.

<br>

## Labels

`Safe` is used for items that are usually disposable, such as build output or app cache.

`Likely Safe` is used for items that can usually be recreated, but may need to be downloaded again.

`Confirm` is used for heavy items that need your judgment, such as large folders, large files, toolchains, and local models.

<br>

## Plain Truth

Scout is local and has no network feature.

It is not Apple-notarized. macOS may warn before opening it.

Scout moves files to Trash, not permanent deletion. Review `Confirm` items before removing them.

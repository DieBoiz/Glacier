# Frequent Issues <!-- omit in toc -->

- [Items are moved to the always-hidden section](#items-are-moved-to-the-always-hidden-section)
- [Glacier removed an item](#glacier-removed-an-item)
- [Glacier does not remember the order of items](#glacier-does-not-remember-the-order-of-items)
- [How do I solve the `Glacier cannot arrange menu bar items in automatically hidden menu bars` error?](#how-do-i-solve-the-glacier-cannot-arrange-menu-bar-items-in-automatically-hidden-menu-bars-error)
- [Glacier keeps asking for permissions that are already granted](#glacier-keeps-asking-for-permissions-that-are-already-granted)

## Items are moved to the always-hidden section

By default, macOS adds new items to the far left of the menu bar, which is also the location of Glacier's always-hidden section. Most apps are configured
to remember the positions of their items, but some are not. macOS treats the items of these apps as new items each time they appear. This results in
these items appearing in the always-hidden section, even if they have been previously been moved.

Glacier does not currently manage individual items, and in fact cannot, as of the current release.

## Glacier removed an item

Glacier does not have the ability to move or remove items. It likely got placed in the always-hidden section by macOS. Option + click the Glacier icon to show
the always-hidden section, then Command + drag the item into a different section.

## Glacier does not remember the order of items

This is not a bug, but a missing feature.

## How do I solve the `Glacier cannot arrange menu bar items in automatically hidden menu bars` error?

1. Open `System Settings` on your Mac
2. Go to `Control Center`
3. Select `Never` for `Automatically hide and show the menu bar`
4. Update your `Menu Bar Items` in `Glacier`
5. Return `Automatically hide and show the menu bar` to your preferred settings

## Glacier keeps asking for permissions that are already granted

This can happen after switching between builds of Glacier, for example when you used a development build before. macOS ties a permission to the code
signature of the app, so an old Accessibility or Screen Recording entry can show as enabled without matching the installed app.

1. Quit Glacier
2. Run `tccutil reset All de.nlmyr.glacier` in Terminal
3. Open Glacier and grant Accessibility and Screen Recording again
4. If Glacier still reports a missing permission, quit and reopen it

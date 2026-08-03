/*
** iwadpicker_cocoa.mm
**
**
**
**---------------------------------------------------------------------------
**
** Copyright 2010 Braden Obrzut
** Copyright 2017-2025 GZDoom Maintainers and Contributors
** Copyright 2025-2026 UZDoom Maintainers and Contributors
**
** SPDX-License-Identifier: GPL-3.0-or-later
**
**---------------------------------------------------------------------------
**
** Code written prior to 2026 is also licensed under:
**
** SPDX-License-Identifier: BSD-3-Clause
**
**---------------------------------------------------------------------------
**
*/

#import "TargetConditionals.h"

#if TARGET_OS_IPHONE

#include <stdio.h>

// GenZD Custom: iOS uses the SwiftUI launcher, so this picker is never shown - the IWAD
// is chosen there and passed through as an argument. But posix/sdl/i_system.cpp still
// declares and calls the pre-ZWidget signature under __APPLE__, so that symbol has to
// exist here. (Upstream only defines the FStartupSelectionInfo overload, which is why
// an Apple + SDL-backend build does not link without this.)
struct WadStuff;
int I_PickIWad_Cocoa(WadStuff *wads, int numwads, bool showwin, int defaultiwad)
{
	printf("GenZD: I_PickIWad_Cocoa called unexpectedly on iOS; defaulting to IWAD 0\n");
	return 0;
}

#else

#include "widgets/launcherwindow.h"

// TODO: get rid of this
int I_PickIWad_Cocoa(FStartupSelectionInfo &info)
{
	return LauncherWindow::ExecModal(info);
}

#endif

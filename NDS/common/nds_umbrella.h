//---------------------------------------------------------------------------------
// nds_umbrella.h -- single header exposed to Swift as the `NDS` module.
//
// Trimmed from MillerTechnologyPeru/swift-embedded-nds's umbrella: Fueling
// only needs core libnds (video/backgrounds/input) -- the UI is a
// software rasterizer into a 16bpp bitmap background (source/Renderer.swift),
// same shape as junkbot-swift's ports/NDS.
//---------------------------------------------------------------------------------
#ifndef FUELING_NDS_UMBRELLA_H
#define FUELING_NDS_UMBRELLA_H

#include <nds.h>
#include <stdlib.h>
#include <dswifi9.h>            // Wifi_InitDefault / Wifi_GetIPInfo
#include <arpa/inet.h>          // struct in_addr
#include <sys/socket.h>         // socket / connect / send / recv
#include <netdb.h>              // gethostbyname, struct hostent
#include "shim.h"

#endif // FUELING_NDS_UMBRELLA_H

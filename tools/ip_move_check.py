#!/usr/bin/env python3
"""Art (technique) names against a block list of the inspiration's move names (KAMPF_PLAN_1000
item 965). Every name in data/moves.json is compared after folding case, spaces, hyphens and
apostrophes; an exact match fails. A name one letter away from a long block-list name is printed
as a note only (Bloom Burst is not a copy just because it is close). The list is base64-encoded
so this file does not spell the names out. Run by tools/ip_check.sh."""
import base64
import json
import os
import re
import sys

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), ".."))
BLOCKED = base64.b64decode(
    "QWJzb3JifEFjY2VsZXJvY2t8QWNpZHxBY3JvYmF0aWNzfEFjdXByZXNzdXJlfEFlcmlhbCBBY2V8QWVyb2JsYXN0fEFnaWxp"
    "dHl8QWlyIEN1dHRlcnxBaXIgU2xhc2h8QW5jaG9yIFNob3R8QXF1YSBKZXR8QXF1YSBSaW5nfEFxdWEgVGFpbHxBcm9tYXRo"
    "ZXJhcHl8QXN0b25pc2h8QXN0cmFsIEJhcnJhZ2V8QXR0YWNrIE9yZGVyfEF0dHJhY3R8QXVyYSBTcGhlcmV8QXVyb3JhIEJl"
    "YW18QXV0b3RvbWl6ZXxBdmFsYW5jaGV8QmFieS1Eb2xsIEV5ZXN8QmFycmFnZXxCYXJyaWVyfEJhdG9uIFBhc3N8QmVhayBC"
    "bGFzdHxCZWhlbW90aCBCYXNofEJlaGVtb3RoIEJsYWRlfEJlbGNofEJlbGx5IERydW18QmlkZXxCaW5kfEJpdGV8Qmxhc3Qg"
    "QnVybnxCbGF6ZSBLaWNrfEJsaXp6YXJkfEJsb2NrfEJsdWUgRmxhcmV8Qm9keSBQcmVzc3xCb2R5IFNsYW18Qm9sdCBTdHJp"
    "a2V8Qm9uZSBDbHVifEJvbmUgUnVzaHxCb25lbWVyYW5nfEJvb21idXJzdHxCcmF2ZSBCaXJkfEJyaW5lfEJydXRhbCBTd2lu"
    "Z3xCdWJibGV8QnViYmxlIEJlYW18QnVnIEJpdGV8QnVnIEJ1enp8QnVsayBVcHxCdWxsZG96ZXxCdWxsZXQgUHVuY2h8QnVs"
    "bGV0IFNlZWR8QnVybiBVcHxCdXJuaW5nIEplYWxvdXN5fENhbG0gTWluZHxDYXB0aXZhdGV8Q2VsZWJyYXRlfENoYXJnZSBC"
    "ZWFtfENoYXJtfENoYXR0ZXJ8Q2hpcCBBd2F5fENpcmNsZSBUaHJvd3xDbGFuZ29yb3VzIFNvdWx8Q2xvc2UgQ29tYmF0fENv"
    "YWNoaW5nfENvaWx8Q29tZXQgUHVuY2h8Q29uZnVzZSBSYXl8Q29uZnVzaW9ufENvbnN0cmljdHxDb252ZXJzaW9ufENvcHlj"
    "YXR8Q29yZSBFbmZvcmNlcnxDb3Jyb3NpdmUgR2FzfENvc21pYyBQb3dlcnxDb3R0b24gU3BvcmV8Q291bnRlcnxDb3VydCBD"
    "aGFuZ2V8Q3JhYmhhbW1lcnxDcm9zcyBDaG9wfENyb3NzIFBvaXNvbnxDcnVuY2h8Q3J1c2ggR3JpcHxEYXJrIFB1bHNlfERh"
    "cmsgVm9pZHxEYXJrZXN0IExhcmlhdHxEYXp6bGluZyBHbGVhbXxEZWZlbmQgT3JkZXJ8RGVmZW5zZSBDdXJsfERlZm9nfERl"
    "c3RpbnkgQm9uZHxEZXRlY3R8RGlhbW9uZCBTdG9ybXxEaWd8RGlzYWJsZXxEaXNhcm1pbmcgVm9pY2V8RGlzY2hhcmdlfERv"
    "b20gRGVzaXJlfERvdWJsZSBIaXR8RG91YmxlIFNsYXB8RG91YmxlIFRlYW18RG91YmxlLUVkZ2V8RHJhY28gTWV0ZW9yfERy"
    "YWdvbiBBc2NlbnR8RHJhZ29uIENsYXd8RHJhZ29uIERhbmNlfERyYWdvbiBFbmVyZ3l8RHJhZ29uIFB1bHNlfERyYWdvbiBS"
    "YWdlfERyYWdvbiBSdXNofERyYWdvbiBUYWlsfERyYWluIFB1bmNofERyYWluaW5nIEtpc3N8RHJlYW0gRWF0ZXJ8RHJpbGwg"
    "UGVja3xEcmlsbCBSdW58RHVhbCBDaG9wfER1YWwgV2luZ2JlYXR8RHluYW1heCBDYW5ub258RHluYW1pYyBQdW5jaHxFYXJ0"
    "aCBQb3dlcnxFYXJ0aHF1YWtlfEVlcmllIFNwZWxsfEVnZyBCb21ifEVsZWN0cmljIFRlcnJhaW58RWxlY3Ryb3dlYnxFbWJh"
    "cmdvfEVtYmVyfEVuY29yZXxFbmR1cmV8RW5lcmd5IEJhbGx8RXJ1cHRpb258RXhwYW5kaW5nIEZvcmNlfEV4cGxvc2lvbnxF"
    "eHRyYXNlbnNvcnl8RXh0cmVtZSBTcGVlZHxGYWludCBBdHRhY2t8RmFpcnkgV2luZHxGYWtlIE91dHxGYWtlIFRlYXJzfEZh"
    "bHNlIFN3aXBlfEZlaW50fEZlbGwgU3RpbmdlcnxGaWVyeSBEYW5jZXxGaWVyeSBXcmF0aHxGaXJlIEJsYXN0fEZpcmUgRmFu"
    "Z3xGaXJlIExhc2h8RmlyZSBQbGVkZ2V8RmlyZSBQdW5jaHxGaXJlIFNwaW58Rmlyc3QgSW1wcmVzc2lvbnxGaXNzdXJlfEZs"
    "YWlsfEZsYW1lIENoYXJnZXxGbGFtZSBXaGVlbHxGbGFtZXRocm93ZXJ8RmxhcmUgQmxpdHp8Rmxhc2ggQ2Fubm9ufEZsZXVy"
    "IENhbm5vbnxGbGluZ3xGbGlwIFR1cm58RmxvcmFsIEhlYWxpbmd8Rm9jdXMgQmxhc3R8Rm9jdXMgRW5lcmd5fEZvcmNlIFBh"
    "bG18Rm9yZXNpZ2h0fEZvcmVzdCdzIEN1cnNlfEZvdWwgUGxheXxGcmVlemUgU2hvY2t8RnJlZXplLURyeXxGcmVlemluZyBH"
    "bGFyZXxGcmVuenkgUGxhbnR8RnJvc3QgQnJlYXRofEZydXN0cmF0aW9ufEZ1cnkgQXR0YWNrfEZ1cnkgQ3V0dGVyfEZ1cnkg"
    "U3dpcGVzfEZ1c2lvbiBCb2x0fEZ1c2lvbiBGbGFyZXxHYXN0cm8gQWNpZHxHZWFyIEdyaW5kfEdlb21hbmN5fEdpZ2EgRHJh"
    "aW58R2lnYSBJbXBhY3R8R2xhY2lhbCBMYW5jZXxHbGFjaWF0ZXxHcmFzcyBLbm90fEdyYXNzIFBsZWRnZXxHcmFzcyBXaGlz"
    "dGxlfEdyYXNzeSBHbGlkZXxHcmFzc3kgVGVycmFpbnxHcmF2aXR5fEdyb3dsfEd1YXJkIFN3YXB8R3VpbGxvdGluZXxHdW5r"
    "IFNob3R8R3VzdHxHeXJvIEJhbGx8SGFtbWVyIEFybXxIYXBweSBIb3VyfEhhcmRlbnxIYXplfEhlYWQgQ2hhcmdlfEhlYWQg"
    "U21hc2h8SGVhZGJ1dHR8SGVhbCBCZWxsfEhlYWwgQmxvY2t8SGVhbCBPcmRlcnxIZWFsaW5nIFdpc2h8SGVhcnQgU3RhbXB8"
    "SGVhcnQgU3dhcHxIZWF0IENyYXNofEhlYXQgV2F2ZXxIZWF2eSBTbGFtfEhleHxIaWRkZW4gUG93ZXJ8SGlnaCBKdW1wIEtp"
    "Y2t8SG9sZCBCYWNrfEhvbGQgSGFuZHN8SG9uZSBDbGF3c3xIb3JuIERyaWxsfEhvcm4gTGVlY2h8SG93bHxIdXJyaWNhbmV8"
    "SHlkcm8gQ2Fubm9ufEh5ZHJvIFB1bXB8SHlwZXIgQmVhbXxIeXBlciBGYW5nfEh5cGVyIFZvaWNlfEh5cGVyc3BhY2UgRnVy"
    "eXxIeXBlcnNwYWNlIEhvbGV8SHlwbm9zaXN8SWNlIEJhbGx8SWNlIEJlYW18SWNlIEJ1cm58SWNlIFB1bmNofEljZSBTaGFy"
    "ZHxJY2ljbGUgQ3Jhc2h8SWNpY2xlIFNwZWFyfEljeSBXaW5kfEluZmVzdGF0aW9ufEluc3RydWN0fElvbiBEZWx1Z2V8SXJv"
    "biBEZWZlbnNlfElyb24gSGVhZHxJcm9uIFRhaWx8SnVkZ21lbnR8SnVtcCBLaWNrfEp1bmdsZSBIZWFsaW5nfEthcmF0ZSBD"
    "aG9wfEtpbmVzaXN8S2luZydzIFNoaWVsZHxLaW5ncyBTaGllbGR8TGFuZCdzIFdyYXRofExhc2ggT3V0fExhc3QgUmVzb3J0"
    "fExhdmEgUGx1bWV8TGVhZiBCbGFkZXxMZWFmIFN0b3JtfExlYWZhZ2V8TGVlY2ggTGlmZXxMZWVjaCBTZWVkfExlZXJ8TGln"
    "aHQgU2NyZWVufExpZ2h0IG9mIFJ1aW58TGlxdWlkYXRpb258TG9jay1PbnxMb3ZlbHkgS2lzc3xMb3cgS2lja3xMdWNreSBD"
    "aGFudHxMdW5hciBEYW5jZXxMdW5nZXxNYWNoIFB1bmNofE1hZ21hIFN0b3JtfE1hZ25ldCBSaXNlfE1hZ25ldGljIEZsdXh8"
    "TWFnbml0dWRlfE1hdCBCbG9ja3xNYXggU3RyaWtlfE1lIEZpcnN0fE1lYW4gTG9va3xNZWdhIERyYWlufE1lZ2EgS2lja3xN"
    "ZWdhIFB1bmNofE1lZ2Fob3JufE1ldGFsIEJ1cnN0fE1ldGFsIFNvdW5kfE1ldGVvciBCZWFtfE1ldGVvciBNYXNofE1ldHJv"
    "bm9tZXxNaWxrIERyaW5rfE1pbWljfE1pbmQgUmVhZGVyfE1pbmltaXplfE1pcmFjbGUgRXllfE1pcnJvciBDb2F0fE1pcnJv"
    "ciBTaG90fE1pc3R5IEV4cGxvc2lvbnxNaXN0eSBUZXJyYWlufE1vb25ibGFzdHxNb29uZ2Vpc3QgQmVhbXxNb29ubGlnaHR8"
    "TW9ybmluZyBTdW58TXVkIFNob3R8TXVkLVNsYXB8TXVkZHkgV2F0ZXJ8TXlzdGljYWwgRmlyZXxOYXN0eSBQbG90fE5hdHVy"
    "YWwgR2lmdHxOaWdodCBTaGFkZXxOaWdodCBTbGFzaHxOaWdodG1hcmV8Tm9ibGUgUm9hcnxOdXp6bGV8T2JsaXZpb24gV2lu"
    "Z3xPY3Rhem9va2F8T2RvciBTbGV1dGh8T21pbm91cyBXaW5kfE9yaWdpbiBQdWxzZXxPdXRyYWdlfE92ZXJoZWF0fFBhaW4g"
    "U3BsaXR8UGFyYWJvbGljIENoYXJnZXxQYXkgRGF5fFBlY2t8UGVyaXNoIFNvbmd8UGV0YWwgQmxpenphcmR8UGV0YWwgRGFu"
    "Y2V8UGhhbnRvbSBGb3JjZXxQaG90b24gR2V5c2VyfFBsYXNtYSBGaXN0c3xQbGF5IFJvdWdofFBsdWNrfFBvaXNvbiBKYWJ8"
    "UG9pc29uIFBvd2RlcnxQb2lzb24gU3Rpbmd8UG9sbGVuIFB1ZmZ8UG9sdGVyZ2Vpc3R8UG91bmR8UG93ZGVyfFBvd2RlciBT"
    "bm93fFBvd2VyIEdlbXxQb3dlciBTd2FwfFBvd2VyIFRyaWNrfFBvd2VyIFRyaXB8UG93ZXIgV2hpcHxQb3dlci1VcCBQdW5j"
    "aHxQcmVjaXBpY2UgQmxhZGVzfFByZXNlbnR8UHJpc21hdGljIExhc2VyfFByb3RlY3R8UHN5YmVhbXxQc3ljaGljfFBzeWNo"
    "aWMgVGVycmFpbnxQc3ljaG8gQm9vc3R8UHN5Y2hvIEN1dHxQc3ljaG8gU2hpZnR8UHN5c2hvY2t8UHN5c3RyaWtlfFB1bmlz"
    "aG1lbnR8UHVyc3VpdHxQeXJvIEJhbGx8UXVpY2sgQXR0YWNrfFF1aXZlciBEYW5jZXxSYWluIERhbmNlfFJhcGlkIFNwaW58"
    "UmF6b3IgTGVhZnxSYXpvciBTaGVsbHxSYXpvciBXaW5kfFJlY292ZXJ8UmVmbGVjdHxSZWxpYyBTb25nfFJldmVyc2FsfFJp"
    "c2luZyBWb2x0YWdlfFJvYXIgb2YgVGltZXxSb2NrIENsaW1ifFJvY2sgUG9saXNofFJvY2sgU2xpZGV8Um9jayBTbWFzaHxS"
    "b2NrIFRocm93fFJvY2sgVG9tYnxSb2NrIFdyZWNrZXJ8Um9sbGluZyBLaWNrfFJvbGxvdXR8Um9vc3R8Um90b3RpbGxlcnxT"
    "YWNyZWQgRmlyZXxTYWNyZWQgU3dvcmR8U2FmZWd1YXJkfFNhbmQgQXR0YWNrfFNhbmQgVG9tYnxTYW5kc3Rvcm18U2NhbGR8"
    "U2NhbGUgU2hvdHxTY2FyeSBGYWNlfFNjb3JjaGluZyBTYW5kc3xTY3JhdGNofFNlYXJpbmcgU2hvdHxTZWNyZXQgU3dvcmR8"
    "U2VlZCBCb21ifFNlZWQgRmxhcmV8U2Vpc21pYyBUb3NzfFNlbGYtRGVzdHJ1Y3R8U2hhZG93IEJhbGx8U2hhZG93IEJvbmV8"
    "U2hhZG93IENsYXd8U2hhZG93IEZvcmNlfFNoYWRvdyBQdW5jaHxTaGFkb3cgU25lYWt8U2hlZXIgQ29sZHxTaGVsbCBTbWFz"
    "aHxTaGVsbCBUcmFwfFNoaWZ0IEdlYXJ8U2lnbmFsIEJlYW18U2lsdmVyIFdpbmR8U2tldGNofFNraXR0ZXIgU21hY2t8U2t1"
    "bGwgQmFzaHxTa3kgQXR0YWNrfFNreSBEcm9wfFNreSBVcHBlcmN1dHxTbGFtfFNsYXNofFNsZWVwIFBvd2RlcnxTbGVlcCBU"
    "YWxrfFNsdWRnZXxTbHVkZ2UgQm9tYnxTbHVkZ2UgV2F2ZXxTbWFjayBEb3dufFNuYXAgVHJhcHxTbmFybHxTbm9yZXxTb2Z0"
    "Ym9pbGVkfFNvbGFyIEJlYW18U29sYXIgQmxhZGV8U29uaWMgQm9vbXxTcGFjaWFsIFJlbmR8U3Bhcmt8U3BhcmtsaW5nIEFy"
    "aWF8U3BlY3RyYWwgVGhpZWZ8U3BpZGVyIFdlYnxTcGlrZXN8U3Bpa3kgU2hpZWxkfFNwaXJpdCBCcmVha3xTcGlyaXQgU2hh"
    "Y2tsZXxTcGxhc2h8U3BvcmV8U3BvdGxpZ2h0fFN0ZWFsdGggUm9ja3xTdGVhbSBFcnVwdGlvbnxTdGVlbCBCZWFtfFN0ZWVs"
    "IFdpbmd8U3RpY2t5IFdlYnxTdG9tcHxTdG9tcGluZyBUYW50cnVtfFN0b25lIEVkZ2V8U3Rvcm0gVGhyb3d8U3RyYW5nZSBT"
    "dGVhbXxTdHJlbmd0aCBTYXB8U3RyaW5nIFNob3R8U3RydWdnbGV8U3RydWdnbGUgQnVnfFN0dW4gU3BvcmV8U3VibWlzc2lv"
    "bnxTdWJzdGl0dXRlfFN1Y2tlciBQdW5jaHxTdW5ueSBEYXl8U3Vuc3RlZWwgU3RyaWtlfFN1cGVyIEZhbmd8U3VwZXJzb25p"
    "Y3xTdXJmfFN1cmdpbmcgU3RyaWtlc3xTd2FnZ2VyfFN3ZWV0IEtpc3N8U3dlZXQgU2NlbnR8U3dpdGNoZXJvb3xTd29yZHMg"
    "RGFuY2V8U3ludGhlc2lzfFRhY2tsZXxUYWlsIFdoaXB8VGFrZSBEb3dufFRhdW50fFRlY2hubyBCbGFzdHxUZWxlcG9ydHxU"
    "ZXJyYWluIFB1bHNlfFRoaWVmfFRob3VzYW5kIEFycm93c3xUaG91c2FuZCBXYXZlc3xUaHJhc2h8VGhyb2F0IENob3B8VGh1"
    "bmRlcnxUaHVuZGVyIENhZ2V8VGh1bmRlciBQdW5jaHxUaHVuZGVyIFNob2NrfFRodW5kZXIgV2F2ZXxUaHVuZGVyYm9sdHxU"
    "aHVuZGVyb3VzIEtpY2t8VGlja2xlfFRvcm1lbnR8VG94aWN8VG94aWMgU3Bpa2VzfFRyYW5zZm9ybXxUcmkgQXR0YWNrfFRy"
    "aWNrIFJvb218VHJpY2stb3ItVHJlYXR8VHJpcGxlIEF4ZWx8VHJpcGxlIEtpY2t8VHJvcCBLaWNrfFRydW1wIENhcmR8VS10"
    "dXJufFYtY3JlYXRlfFZhY3V1bSBXYXZlfFZlbm9tIERyZW5jaHxWZW5vc2hvY2t8VmluZSBXaGlwfFZpc2UgR3JpcHxWaXRh"
    "bCBUaHJvd3xWb2x0IFN3aXRjaHxWb2x0IFRhY2tsZXxXYWtlLVVwIFNsYXB8V2F0ZXIgR3VufFdhdGVyIFBsZWRnZXxXYXRl"
    "ciBTaHVyaWtlbnxXYXRlciBTcG91dHxXYXRlcmZhbGx8V2VhdGhlciBCYWxsfFdoaXJscG9vbHxXaWNrZWQgQmxvd3xXaWxk"
    "IENoYXJnZXxXaWxsLU8tV2lzcHxXaW5nIEF0dGFja3xXaXRoZHJhd3xXb29kIEhhbW1lcnxXb3JrIFVwfFdvcnJ5IFNlZWR8"
    "V3JhcHxXcmluZyBPdXR8WC1TY2lzc29yfFphcCBDYW5ub258WmVuIEhlYWRidXR0fFppbmcgWmFw"
).decode().split("|")
## Names at least this long (folded) get the one-letter note.
NEAR_MIN = 8


def fold(name):
    return re.sub(r"[^a-z]", "", name.lower())


def near(a, b):
    """True when a and b differ by one edit (insert, delete or swap of one letter)."""
    if abs(len(a) - len(b)) > 1 or a == b:
        return False
    if len(a) == len(b):
        return sum(x != y for x, y in zip(a, b)) == 1
    s, l = (a, b) if len(a) < len(b) else (b, a)
    return any(l[:i] + l[i + 1:] == s for i in range(len(l)))


def check(names):
    """Returns ([exact hits], [near notes]) as (name, block-list entry) pairs."""
    blocked = {fold(n): n for n in BLOCKED}
    hits, notes = [], []
    for n in names:
        f = fold(n)
        if f in blocked:
            hits.append((n, blocked[f]))
            continue
        for bf, b in blocked.items():
            if len(bf) >= NEAR_MIN and near(f, bf):
                notes.append((n, b))
    return hits, notes


def main():
    # Self-test: the gate must still catch a planted name, folded either way.
    planted = BLOCKED[len(BLOCKED) // 2]
    if not check([planted.upper(), planted.replace(" ", "-")])[0]:
        print("::error::tools/ip_move_check.py no longer catches a block-list name.")
        return 1
    moves = json.load(open(os.path.join(ROOT, "data", "moves.json")))
    hits, notes = check([str(m.get("name", "")) for m in moves])
    for n, b in notes:
        print("note: art name '%s' is one letter from a block-list name; fine if it reads as our own" % n)
    for n, b in hits:
        print("data/moves.json: art name '%s' is on the move block list" % n)
    if hits:
        print("::error::An art name copies one of the inspiration's moves (lines above). Pick our own name.")
        return 1
    print("Art names OK (%d arts against %d block-list names)" % (len(moves), len(BLOCKED)))
    return 0


if __name__ == "__main__":
    sys.exit(main())

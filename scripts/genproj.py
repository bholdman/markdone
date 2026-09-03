#!/usr/bin/env python3
"""Generate a minimal, valid Xcode project for MarkDone."""
import os

ROOT = "/Users/brianh/Projects/markdowner"
PROJ = os.path.join(ROOT, "MarkDone.xcodeproj")
os.makedirs(PROJ, exist_ok=True)

_counter = [0]
def uid():
    _counter[0] += 1
    return f"{_counter[0]:024X}"

sources = [
    "MarkDoneApp.swift",
    "Theme.swift",
    "Document.swift",
    "DocumentStore.swift",
    "SyncModel.swift",
    "HotKeyManager.swift",
    "MarkdownWebView.swift",
    "CodeEditorView.swift",
    "EditorPane.swift",
    "TabBarView.swift",
    "StatusBarView.swift",
    "RootView.swift",
]
# Files physically under MarkDone/Resources/
web_resources = [
    "marked.min.js",
    "highlight.min.js",
    "turndown.min.js",
    "turndown-plugin-gfm.js",
    "github-markdown.css",
    "hl-github.min.css",
    "hl-github-dark.min.css",
]
ASSET_CATALOG = "Assets.xcassets"          # under MarkDone/
ENTITLEMENTS = "MarkDone.entitlements"   # under MarkDone/

# --- assign ids ---
file_refs = {}
build_files = {}
for p in sources + web_resources + [ASSET_CATALOG, ENTITLEMENTS]:
    file_refs[p] = uid()
for p in sources + web_resources + [ASSET_CATALOG]:
    build_files[p] = uid()

PROJECT = uid(); MAIN_GROUP = uid(); MARKDOWNER_GROUP = uid()
RESOURCES_GROUP = uid(); PRODUCTS_GROUP = uid()
TARGET = uid(); PRODUCT_REF = uid()
SOURCES_PHASE = uid(); RESOURCES_PHASE = uid(); FRAMEWORKS_PHASE = uid()
PROJ_CFG_LIST = uid(); TARGET_CFG_LIST = uid()
PROJ_DEBUG = uid(); PROJ_RELEASE = uid(); TARGET_DEBUG = uid(); TARGET_RELEASE = uid()

def ftype(path):
    if path.endswith(".swift"): return "sourcecode.swift"
    if path.endswith(".js"): return "sourcecode.javascript"
    if path.endswith(".css"): return "text.css"
    if path.endswith(".xcassets"): return "folder.assetcatalog"
    if path.endswith(".entitlements"): return "text.plist.entitlements"
    return "text"

L = []
w = L.append
w("// !$*UTF8*$!")
w("{")
w("\tarchiveVersion = 1;")
w("\tclasses = {")
w("\t};")
w("\tobjectVersion = 56;")
w("\tobjects = {")

w("\n/* Begin PBXBuildFile section */")
for p in sources:
    n = os.path.basename(p)
    w(f"\t\t{build_files[p]} /* {n} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_refs[p]} /* {n} */; }};")
for p in web_resources + [ASSET_CATALOG]:
    n = os.path.basename(p)
    w(f"\t\t{build_files[p]} /* {n} in Resources */ = {{isa = PBXBuildFile; fileRef = {file_refs[p]} /* {n} */; }};")
w("/* End PBXBuildFile section */")

w("\n/* Begin PBXFileReference section */")
w(f'\t\t{PRODUCT_REF} /* MarkDone.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = MarkDone.app; sourceTree = BUILT_PRODUCTS_DIR; }};')
for p in sources + [ASSET_CATALOG, ENTITLEMENTS]:
    n = os.path.basename(p)
    w(f'\t\t{file_refs[p]} /* {n} */ = {{isa = PBXFileReference; lastKnownFileType = {ftype(p)}; path = "{n}"; sourceTree = "<group>"; }};')
for p in web_resources:
    n = os.path.basename(p)
    w(f'\t\t{file_refs[p]} /* {n} */ = {{isa = PBXFileReference; lastKnownFileType = {ftype(p)}; path = "{n}"; sourceTree = "<group>"; }};')
w("/* End PBXFileReference section */")

w("\n/* Begin PBXFrameworksBuildPhase section */")
w(f"\t\t{FRAMEWORKS_PHASE} = {{")
w("\t\t\tisa = PBXFrameworksBuildPhase;")
w("\t\t\tbuildActionMask = 2147483647;")
w("\t\t\tfiles = (\n\t\t\t);")
w("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
w("\t\t};")
w("/* End PBXFrameworksBuildPhase section */")

w("\n/* Begin PBXGroup section */")
w(f"\t\t{MAIN_GROUP} = {{")
w("\t\t\tisa = PBXGroup;")
w("\t\t\tchildren = (")
w(f"\t\t\t\t{MARKDOWNER_GROUP} /* MarkDone */,")
w(f"\t\t\t\t{PRODUCTS_GROUP} /* Products */,")
w("\t\t\t);")
w("\t\t\tsourceTree = \"<group>\";")
w("\t\t};")
w(f"\t\t{MARKDOWNER_GROUP} /* MarkDone */ = {{")
w("\t\t\tisa = PBXGroup;")
w("\t\t\tchildren = (")
for p in sources:
    w(f"\t\t\t\t{file_refs[p]} /* {os.path.basename(p)} */,")
w(f"\t\t\t\t{file_refs[ASSET_CATALOG]} /* {ASSET_CATALOG} */,")
w(f"\t\t\t\t{RESOURCES_GROUP} /* Resources */,")
w(f"\t\t\t\t{file_refs[ENTITLEMENTS]} /* {ENTITLEMENTS} */,")
w("\t\t\t);")
w("\t\t\tpath = MarkDone;")
w("\t\t\tsourceTree = \"<group>\";")
w("\t\t};")
w(f"\t\t{RESOURCES_GROUP} /* Resources */ = {{")
w("\t\t\tisa = PBXGroup;")
w("\t\t\tchildren = (")
for p in web_resources:
    w(f"\t\t\t\t{file_refs[p]} /* {os.path.basename(p)} */,")
w("\t\t\t);")
w("\t\t\tpath = Resources;")
w("\t\t\tsourceTree = \"<group>\";")
w("\t\t};")
w(f"\t\t{PRODUCTS_GROUP} /* Products */ = {{")
w("\t\t\tisa = PBXGroup;")
w("\t\t\tchildren = (")
w(f"\t\t\t\t{PRODUCT_REF} /* MarkDone.app */,")
w("\t\t\t);")
w("\t\t\tname = Products;")
w("\t\t\tsourceTree = \"<group>\";")
w("\t\t};")
w("/* End PBXGroup section */")

w("\n/* Begin PBXNativeTarget section */")
w(f"\t\t{TARGET} /* MarkDone */ = {{")
w("\t\t\tisa = PBXNativeTarget;")
w(f"\t\t\tbuildConfigurationList = {TARGET_CFG_LIST} /* Build configuration list for PBXNativeTarget \"MarkDone\" */;")
w("\t\t\tbuildPhases = (")
w(f"\t\t\t\t{SOURCES_PHASE} /* Sources */,")
w(f"\t\t\t\t{FRAMEWORKS_PHASE} /* Frameworks */,")
w(f"\t\t\t\t{RESOURCES_PHASE} /* Resources */,")
w("\t\t\t);")
w("\t\t\tbuildRules = (\n\t\t\t);")
w("\t\t\tdependencies = (\n\t\t\t);")
w("\t\t\tname = MarkDone;")
w("\t\t\tproductName = MarkDone;")
w(f"\t\t\tproductReference = {PRODUCT_REF} /* MarkDone.app */;")
w("\t\t\tproductType = \"com.apple.product-type.application\";")
w("\t\t};")
w("/* End PBXNativeTarget section */")

w("\n/* Begin PBXProject section */")
w(f"\t\t{PROJECT} /* Project object */ = {{")
w("\t\t\tisa = PBXProject;")
w("\t\t\tattributes = {")
w("\t\t\t\tBuildIndependentTargetsInParallel = 1;")
w("\t\t\t\tLastSwiftUpdateCheck = 2650;")
w("\t\t\t\tLastUpgradeCheck = 2650;")
w("\t\t\t\tTargetAttributes = {")
w(f"\t\t\t\t\t{TARGET} = {{ CreatedOnToolsVersion = 26.5; }};")
w("\t\t\t\t};")
w("\t\t\t};")
w(f"\t\t\tbuildConfigurationList = {PROJ_CFG_LIST} /* Build configuration list for PBXProject */;")
w("\t\t\tcompatibilityVersion = \"Xcode 14.0\";")
w("\t\t\tdevelopmentRegion = en;")
w("\t\t\thasScannedForEncodings = 0;")
w("\t\t\tknownRegions = (\n\t\t\t\ten,\n\t\t\t\tBase,\n\t\t\t);")
w(f"\t\t\tmainGroup = {MAIN_GROUP};")
w(f"\t\t\tproductRefGroup = {PRODUCTS_GROUP} /* Products */;")
w("\t\t\tprojectDirPath = \"\";")
w("\t\t\tprojectRoot = \"\";")
w("\t\t\ttargets = (")
w(f"\t\t\t\t{TARGET} /* MarkDone */,")
w("\t\t\t);")
w("\t\t};")
w("/* End PBXProject section */")

w("\n/* Begin PBXResourcesBuildPhase section */")
w(f"\t\t{RESOURCES_PHASE} = {{")
w("\t\t\tisa = PBXResourcesBuildPhase;")
w("\t\t\tbuildActionMask = 2147483647;")
w("\t\t\tfiles = (")
for p in [ASSET_CATALOG] + web_resources:
    w(f"\t\t\t\t{build_files[p]} /* {os.path.basename(p)} in Resources */,")
w("\t\t\t);")
w("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
w("\t\t};")
w("/* End PBXResourcesBuildPhase section */")

w("\n/* Begin PBXSourcesBuildPhase section */")
w(f"\t\t{SOURCES_PHASE} = {{")
w("\t\t\tisa = PBXSourcesBuildPhase;")
w("\t\t\tbuildActionMask = 2147483647;")
w("\t\t\tfiles = (")
for p in sources:
    w(f"\t\t\t\t{build_files[p]} /* {os.path.basename(p)} in Sources */,")
w("\t\t\t);")
w("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
w("\t\t};")
w("/* End PBXSourcesBuildPhase section */")

common_debug = """\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;
\t\t\t\tCLANG_ENABLE_MODULES = YES;
\t\t\t\tCLANG_ENABLE_OBJC_ARC = YES;
\t\t\t\tCOPY_PHASE_STRIP = NO;
\t\t\t\tDEBUG_INFORMATION_FORMAT = dwarf;
\t\t\t\tENABLE_TESTABILITY = YES;
\t\t\t\tGCC_OPTIMIZATION_LEVEL = 0;
\t\t\t\tGCC_PREPROCESSOR_DEFINITIONS = (
\t\t\t\t\t"DEBUG=1",
\t\t\t\t\t"$(inherited)",
\t\t\t\t);
\t\t\t\tMACOSX_DEPLOYMENT_TARGET = 14.0;
\t\t\t\tONLY_ACTIVE_ARCH = YES;
\t\t\t\tSDKROOT = macosx;
\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;
\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = "-Onone";"""

common_release = """\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;
\t\t\t\tCLANG_ENABLE_MODULES = YES;
\t\t\t\tCLANG_ENABLE_OBJC_ARC = YES;
\t\t\t\tDEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
\t\t\t\tENABLE_NS_ASSERTIONS = NO;
\t\t\t\tMACOSX_DEPLOYMENT_TARGET = 14.0;
\t\t\t\tSDKROOT = macosx;
\t\t\t\tSWIFT_COMPILATION_MODE = wholemodule;
\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = "-O";"""

target_common = """\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
\t\t\t\tASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
\t\t\t\tCODE_SIGN_ENTITLEMENTS = MarkDone/MarkDone.entitlements;
\t\t\t\tCODE_SIGN_IDENTITY = "-";
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCOMBINE_HIDPI_IMAGES = YES;
\t\t\t\tCURRENT_PROJECT_VERSION = 1;
\t\t\t\tENABLE_HARDENED_RUNTIME = NO;
\t\t\t\tGENERATE_INFOPLIST_FILE = YES;
\t\t\t\tINFOPLIST_FILE = MarkDone/Info.plist;
\t\t\t\tINFOPLIST_KEY_CFBundleDisplayName = MarkDone;
\t\t\t\tINFOPLIST_KEY_LSApplicationCategoryType = "public.app-category.productivity";
\t\t\t\tINFOPLIST_KEY_NSHumanReadableCopyright = "";
\t\t\t\tMARKETING_VERSION = 0.2.0;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.codefiworks.MarkDone;
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;
\t\t\t\tSWIFT_VERSION = 5.0;"""

w("\n/* Begin XCBuildConfiguration section */")
for cid, name, body in [(PROJ_DEBUG, "Debug", common_debug), (PROJ_RELEASE, "Release", common_release)]:
    w(f"\t\t{cid} /* {name} */ = {{")
    w("\t\t\tisa = XCBuildConfiguration;")
    w("\t\t\tbuildSettings = {")
    w(body)
    w("\t\t\t};")
    w(f"\t\t\tname = {name};")
    w("\t\t};")
for cid, name in [(TARGET_DEBUG, "Debug"), (TARGET_RELEASE, "Release")]:
    w(f"\t\t{cid} /* {name} */ = {{")
    w("\t\t\tisa = XCBuildConfiguration;")
    w("\t\t\tbuildSettings = {")
    w(target_common)
    w("\t\t\t};")
    w(f"\t\t\tname = {name};")
    w("\t\t};")
w("/* End XCBuildConfiguration section */")

w("\n/* Begin XCConfigurationList section */")
w(f"\t\t{PROJ_CFG_LIST} /* Build configuration list for PBXProject */ = {{")
w("\t\t\tisa = XCConfigurationList;")
w("\t\t\tbuildConfigurations = (")
w(f"\t\t\t\t{PROJ_DEBUG} /* Debug */,")
w(f"\t\t\t\t{PROJ_RELEASE} /* Release */,")
w("\t\t\t);")
w("\t\t\tdefaultConfigurationIsVisible = 0;")
w("\t\t\tdefaultConfigurationName = Release;")
w("\t\t};")
w(f"\t\t{TARGET_CFG_LIST} /* Build configuration list for PBXNativeTarget \"MarkDone\" */ = {{")
w("\t\t\tisa = XCConfigurationList;")
w("\t\t\tbuildConfigurations = (")
w(f"\t\t\t\t{TARGET_DEBUG} /* Debug */,")
w(f"\t\t\t\t{TARGET_RELEASE} /* Release */,")
w("\t\t\t);")
w("\t\t\tdefaultConfigurationIsVisible = 0;")
w("\t\t\tdefaultConfigurationName = Release;")
w("\t\t};")
w("/* End XCConfigurationList section */")

w("\t};")
w(f"\trootObject = {PROJECT} /* Project object */;")
w("}")

with open(os.path.join(PROJ, "project.pbxproj"), "w") as f:
    f.write("\n".join(L) + "\n")
print("Wrote", os.path.join(PROJ, "project.pbxproj"))

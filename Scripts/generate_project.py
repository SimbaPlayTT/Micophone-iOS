#!/usr/bin/env python3
"""Reproduce the checked-in Xcode project using Python's standard library only."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def uid(key):
    return hashlib.sha1(key.encode()).hexdigest()[:24].upper()


def render(value):
    if isinstance(value, dict):
        return '{ ' + ' '.join(f'{json.dumps(k)} = {render(v)};' for k, v in value.items()) + ' }'
    if isinstance(value, list):
        return '( ' + ', '.join(render(v) for v in value) + (' ,' if value else '') + ' )'
    return json.dumps(str(value))


def generate():
    objects = {}

    def add(key, isa, **fields):
        identifier = uid(key)
        objects[identifier] = dict(isa=isa, **fields)
        return identifier

    app = uid('app-target')
    tests = uid('tests-target')
    project = uid('project')
    product = add('app-product', 'PBXFileReference', explicitFileType='wrapper.application', path='Micophone-iOS.app', sourceTree='BUILT_PRODUCTS_DIR')
    test_product = add('test-product', 'PBXFileReference', explicitFileType='wrapper.cfbundle', path='MicophoneTests.xctest', sourceTree='BUILT_PRODUCTS_DIR')

    def reference(path, kind):
        return add('ref:' + path, 'PBXFileReference', lastKnownFileType=kind, path=path, sourceTree='<group>')

    app_sources = sorted(p.relative_to(ROOT).as_posix() for p in (ROOT / 'Micophone-iOS').rglob('*.swift'))
    test_sources = sorted(p.relative_to(ROOT).as_posix() for p in (ROOT / 'Tests').rglob('*.swift'))
    app_resources = ['Micophone-iOS/Resources/LICENSE.txt', 'Micophone-iOS/Resources/PrivacyInfo.xcprivacy', 'Micophone-iOS/Resources/Assets.xcassets']
    test_resources = ['Tests/Core/Fixtures/protocol-v2.json']
    all_paths = app_sources + test_sources + app_resources + test_resources + ['Micophone-iOS/Info.plist']
    types = {'.swift': 'sourcecode.swift', '.plist': 'text.plist.xml', '.xcprivacy': 'text.xml', '.json': 'text.json', '.xcassets': 'folder.assetcatalog'}
    refs = {p: reference(p, types.get(Path(p).suffix, 'text')) for p in all_paths}

    def phase(key, kind, paths):
        files = [add(f'build:{key}:{p}', 'PBXBuildFile', fileRef=refs[p]) for p in paths]
        return add(key, kind, buildActionMask='2147483647', files=files, runOnlyForDeploymentPostprocessing='0')

    app_phases = [phase('app-sources', 'PBXSourcesBuildPhase', app_sources), phase('app-frameworks', 'PBXFrameworksBuildPhase', []), phase('app-resources', 'PBXResourcesBuildPhase', app_resources)]
    test_phases = [phase('test-sources', 'PBXSourcesBuildPhase', test_sources), phase('test-frameworks', 'PBXFrameworksBuildPhase', []), phase('test-resources', 'PBXResourcesBuildPhase', test_resources)]
    source_group = add('sources-group', 'PBXGroup', children=[refs[p] for p in app_sources + app_resources + ['Micophone-iOS/Info.plist']], name='Application', sourceTree='<group>')
    test_group = add('tests-group', 'PBXGroup', children=[refs[p] for p in test_sources + test_resources], name='Tests', sourceTree='<group>')
    products = add('products-group', 'PBXGroup', children=[product, test_product], name='Products', sourceTree='<group>')
    main = add('main-group', 'PBXGroup', children=[source_group, test_group, products], sourceTree='<group>')
    common = dict(IPHONEOS_DEPLOYMENT_TARGET='16.0', SDKROOT='iphoneos', SWIFT_VERSION='5.0', CLANG_ENABLE_MODULES='YES', CLANG_ENABLE_OBJC_ARC='YES', TARGETED_DEVICE_FAMILY='1,2', ENABLE_USER_SCRIPT_SANDBOXING='YES')

    def configurations(key, base):
        configs = []
        for name in ['Debug', 'Release']:
            settings = dict(base)
            settings.update(SWIFT_OPTIMIZATION_LEVEL='-Onone' if name == 'Debug' else '-O', DEBUG_INFORMATION_FORMAT='dwarf' if name == 'Debug' else 'dwarf-with-dsym')
            if name == 'Debug':
                settings.update(SWIFT_ACTIVE_COMPILATION_CONDITIONS='DEBUG', ENABLE_TESTABILITY='YES')
            configs.append(add(key + name, 'XCBuildConfiguration', name=name, buildSettings=settings))
        return add(key, 'XCConfigurationList', buildConfigurations=configs, defaultConfigurationIsVisible='0', defaultConfigurationName='Release')

    project_configs = configurations('project-configs', common)
    app_configs = configurations('app-configs', dict(PRODUCT_NAME='Micophone-iOS', PRODUCT_MODULE_NAME='Micophone_iOS', PRODUCT_BUNDLE_IDENTIFIER='org.micophone.ios', INFOPLIST_FILE='Micophone-iOS/Info.plist', GENERATE_INFOPLIST_FILE='NO', CODE_SIGN_STYLE='Automatic', DEVELOPMENT_TEAM='', MARKETING_VERSION='1.0.0', CURRENT_PROJECT_VERSION='1', ASSETCATALOG_COMPILER_APPICON_NAME='AppIcon', SWIFT_EMIT_LOC_STRINGS='YES', LD_RUNPATH_SEARCH_PATHS=['$(inherited)', '@executable_path/Frameworks']))
    test_configs = configurations('test-configs', dict(PRODUCT_NAME='MicophoneTests', PRODUCT_MODULE_NAME='MicophoneTests', PRODUCT_BUNDLE_IDENTIFIER='org.micophone.ios.tests', GENERATE_INFOPLIST_FILE='YES', CODE_SIGN_STYLE='Automatic', TEST_HOST='$(BUILT_PRODUCTS_DIR)/Micophone-iOS.app/Micophone-iOS', BUNDLE_LOADER='$(TEST_HOST)', LD_RUNPATH_SEARCH_PATHS=['$(inherited)', '@executable_path/Frameworks', '@loader_path/Frameworks']))
    proxy = add('test-proxy', 'PBXContainerItemProxy', containerPortal=project, proxyType='1', remoteGlobalIDString=app, remoteInfo='Micophone-iOS')
    dependency = add('test-dependency', 'PBXTargetDependency', target=app, targetProxy=proxy)
    add('app-target', 'PBXNativeTarget', buildConfigurationList=app_configs, buildPhases=app_phases, buildRules=[], dependencies=[], name='Micophone-iOS', productName='Micophone-iOS', productReference=product, productType='com.apple.product-type.application')
    add('tests-target', 'PBXNativeTarget', buildConfigurationList=test_configs, buildPhases=test_phases, buildRules=[], dependencies=[dependency], name='MicophoneTests', productName='MicophoneTests', productReference=test_product, productType='com.apple.product-type.bundle.unit-test')
    add('project', 'PBXProject', attributes=dict(BuildIndependentTargetsInParallel='YES', LastUpgradeCheck='1600', TargetAttributes={app: dict(CreatedOnToolsVersion='16.0', SystemCapabilities={'com.apple.BackgroundModes': {'enabled': '1'}}), tests: dict(CreatedOnToolsVersion='16.0', TestTargetID=app)}), buildConfigurationList=project_configs, compatibilityVersion='Xcode 14.0', developmentRegion='en', hasScannedForEncodings='0', knownRegions=['en', 'Base'], mainGroup=main, productRefGroup=products, projectDirPath='', projectRoot='', targets=[app, tests])
    output = ROOT / 'Micophone-iOS.xcodeproj'
    output.mkdir(exist_ok=True)
    (output / 'project.pbxproj').write_text('// !$*UTF8*$!\n' + render(dict(archiveVersion='1', classes={}, objectVersion='56', objects=objects, rootObject=project)) + '\n', encoding='utf-8')
    scheme_dir = output / 'xcshareddata' / 'xcschemes'
    scheme_dir.mkdir(parents=True, exist_ok=True)
    def buildref(identifier, name, target):
        return f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{identifier}" BuildableName="{name}" BlueprintName="{target}" ReferencedContainer="container:Micophone-iOS.xcodeproj"/>'
    appref = buildref(app, 'Micophone-iOS.app', 'Micophone-iOS')
    testref = buildref(tests, 'MicophoneTests.xctest', 'MicophoneTests')
    scheme = f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries>
<BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{appref}</BuildActionEntry>
</BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO">{testref}</TestableReference></Testables></TestAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{appref}</BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{appref}</BuildableProductRunnable></ProfileAction>
<AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>
'''
    (scheme_dir / 'Micophone-iOS.xcscheme').write_text(scheme, encoding='utf-8')
    print(f'Generated project with {len(app_sources)} application files and {len(test_sources)} test files.')


if __name__ == '__main__':
    generate()

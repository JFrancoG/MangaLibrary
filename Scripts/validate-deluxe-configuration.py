#!/usr/bin/env python3
"""Validate the actual Deluxe target graph and unfiltered release test selection."""

import json
from pathlib import Path
import subprocess
import sys
import xml.etree.ElementTree as ET


ROOT = Path(__file__).resolve().parent.parent
PROJECT = "MangaLibrary.xcodeproj"
EXPECTED_TARGETS = {
    "MangaLibrary": "com.apple.product-type.application",
    "MangaLibraryWidgetExtension": "com.apple.product-type.app-extension",
    "MangaLibraryWatch Watch App": "com.apple.product-type.application",
    "MangaLibraryTests": "com.apple.product-type.bundle.unit-test",
    "MangaLibraryUITests": "com.apple.product-type.bundle.ui-testing",
}


def require(condition, message):
    if not condition:
        raise ValueError(message)


def validate():
    project = json.loads(subprocess.check_output([
        "/usr/bin/plutil", "-convert", "json", "-o", "-",
        str(ROOT / PROJECT / "project.pbxproj"),
    ]))
    objects = project["objects"]
    target_ids = objects[project["rootObject"]]["targets"]
    targets = {objects[key]["name"]: key for key in target_ids}
    require(set(targets) == set(EXPECTED_TARGETS), "El inventario Deluxe debe cubrir los cinco targets reales.")
    require(len(target_ids) == len(targets), "El proyecto contiene nombres de target duplicados.")
    for name, kind in EXPECTED_TARGETS.items():
        target = objects[targets[name]]
        require(target["isa"] == "PBXNativeTarget" and target["productType"] == kind,
                f"Tipo de producto inesperado: {name}.")

    app = objects[targets["MangaLibrary"]]
    dependencies = {objects[key].get("target") for key in app.get("dependencies", [])}
    for name in ("MangaLibraryWidgetExtension", "MangaLibraryWatch Watch App"):
        require(targets[name] in dependencies, f"La app debe construir su dependencia {name}.")

    schemes = ROOT / PROJECT / "xcshareddata/xcschemes"
    for name, runnable in (("MangaLibrary", "MangaLibrary"),
                           ("MangaLibraryWatch Watch App", "MangaLibraryWatch Watch App")):
        scheme = ET.parse(schemes / f"{name}.xcscheme").getroot()
        build = scheme.find("BuildAction")
        require(build is not None and build.get("buildImplicitDependencies") == "YES",
                f"{name}: dependencias implícitas deshabilitadas.")
        entries = build.findall("BuildActionEntries/BuildActionEntry")
        references = []
        for entry in entries:
            ref = entry.find("BuildableReference")
            require(ref is not None and ref.get("BlueprintIdentifier") in target_ids,
                    f"{name}: referencia de build ajena al proyecto.")
            require(ref.get("ReferencedContainer") == f"container:{PROJECT}",
                    f"{name}: contenedor de build incorrecto.")
            require(entry.get("buildForTesting") == "YES" and entry.get("buildForArchiving") == "YES",
                    f"{name}: producto excluido de testing o archive.")
            references.append(ref.get("BlueprintIdentifier"))
        require(targets[runnable] in references, f"{name}: falta su producto en BuildAction.")
        run_ref = scheme.find("LaunchAction/BuildableProductRunnable/BuildableReference")
        require(run_ref is not None and run_ref.get("BlueprintIdentifier") == targets[runnable],
                f"{name}: ejecutable inesperado.")

    for name in ("Fast", "Integration", "UI", "ReleaseGate"):
        plan = json.loads((ROOT / "TestPlans" / f"{name}.xctestplan").read_text())
        require(len(plan["configurations"]) == 1 and not plan["configurations"][0].get("options"),
                f"{name}: las opciones por configuración requieren revisar la selección efectiva.")
        actual_targets = []
        for entry in plan["testTargets"]:
            ref = entry["target"]
            target_name = ref["name"]
            require(ref["identifier"] == targets.get(target_name)
                    and ref["containerPath"] == f"container:{PROJECT}",
                    f"{name}: identidad real del target incorrecta.")
            require(entry.get("enabled", True) is True and not entry.get("skipped", False),
                    f"{name}: target deshabilitado o excluido.")
            actual_targets.append(target_name)
        if name == "ReleaseGate":
            test_targets = {name for name, kind in EXPECTED_TARGETS.items() if ".bundle." in kind}
            require(set(actual_targets) == test_targets and len(actual_targets) == len(test_targets),
                    "ReleaseGate debe incluir una vez todos los targets de test.")
        if name != "UI":
            arguments = plan["defaultOptions"].get("commandLineArgumentEntries", [])
            require(arguments == [{"argument": "-ui-testing"}]
                    or arguments == [{"argument": "-ui-testing", "enabled": True}],
                    f"{name}: el host sintético debe estar habilitado sin argumentos alternativos.")

    print("Deluxe: cinco targets reales, dependencias y schemes coherentes; selección de tests habilitada.")
    print("Alcance: estructura estática; no ejecuta build, tests, DocC ni pruebas físicas.")


if __name__ == "__main__":
    try:
        validate()
    except (ValueError, KeyError, OSError, subprocess.CalledProcessError, ET.ParseError) as error:
        print(f"error: {str(error).replace(str(ROOT), '<repository>')}", file=sys.stderr)
        sys.exit(1)

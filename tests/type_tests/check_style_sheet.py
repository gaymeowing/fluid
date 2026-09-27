"""Check valid styles and ensure invalid styles produce Solver V2 diagnostics."""

from pathlib import Path
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
FIXTURES = Path(__file__).resolve().parent

INVALID = {
    "color_transparency": 'style_sheet():rule("Frame")({BackgroundTransparency = Color3.new()})',
    "query_color_transparency": 'type P = style_sheet.StyleProperties<"Frame", {}>; local query: index<index<P, "queries"> & {}, string> = {BackgroundTransparency = Color3.new()}; print(query)',
    "method_key": 'local key: keyof<style_sheet.StyleProperties<"Frame", {}>> = "Destroy"; print(key)',
    "transition_signal_key": 'type P = style_sheet.StyleProperties<"TextButton", {}>; local key: keyof<index<P, "Transition"> & {}> = "Activated"; print(key)',
    "transition_wrong_class_key": 'type P = style_sheet.StyleProperties<"Frame", {}>; local key: keyof<index<P, "Transition"> & {}> = "TextSize"; print(key)',
    "frame_text_size": 'local key: keyof<style_sheet.StyleProperties<"Frame", {}>> = "TextSize"; print(key)',
    "wrong_value": 'style_sheet():rule("TextLabel")({TextSize = "large"})',
    "missing_token": 'style_sheet():tokens({Alpha = 1}):rule("Frame")({BackgroundTransparency = "$Missing"})',
    "wrong_token_type": 'style_sheet():tokens({Color = Color3.new()}):rule("Frame")({BackgroundTransparency = "$Color"})',
    "wrong_enum_token": 'style_sheet():tokens({Mode = Enum.AutomaticSize.X}):rule("Frame")({SizeConstraint = "$Mode"})',
    "signal_key": 'local key: keyof<style_sheet.StyleProperties<"TextButton", {}>> = "Activated"; print(key)',
    "inherited_signal_key": 'local key: keyof<style_sheet.StyleProperties<"Frame", {}>> = "Changed"; print(key)',
    "transition_value": 'style_sheet():rule("Frame")({Transition = {Default = 1}})',
    "unknown_tag": 'style_sheet():rule("Frame.known")({}):tags({"missing"})',
    "unknown_reactive_tag": 'style_sheet():rule("Frame.known")({}):tags({function(): "missing" return "missing" end})',
    "tag_after_tokens": 'style_sheet():rule("Frame.known")({}):tokens({Alpha = 1}):tags({"missing"})',
    "tag_after_derive": 'style_sheet():derive(style_sheet():rule("Frame.known")({})):tags({"missing"})',
    "query_type": 'type P = style_sheet.StyleProperties<"Frame", {}>; local query: index<index<P, "queries"> & {}, string> = {Size = Vector2.new()}; print(query)',
    "phantom_type": 'style_sheet():rule(".tag::UICorner #Named")({CornerRadius = 12})',
    "selector_list_type": 'style_sheet():rule("TextLabel.a, TextButton.b")({TextSize = "large"})',
    "annotated_selector_token": 'style_sheet():tokens({Alpha = 1}):rule("Frame" :: "Frame")({BackgroundTransparency = "$Missing"})',
    "token_overwrite": 'style_sheet():tokens({Alpha = 1}):tokens({Alpha = Color3.new()}):rule("Frame")({BackgroundTransparency = "$Alpha"})',
    "derive_local_precedence": 'style_sheet():tokens({Alpha = Color3.new()}):derive(style_sheet():tokens({Alpha = 1})):rule("Frame")({BackgroundTransparency = "$Alpha"})',
}


def main():
    with tempfile.TemporaryDirectory(prefix="style_sheet_", dir=FIXTURES) as directory:
        generated = Path(directory)
        negatives = []
        for name, source in INVALID.items():
            path = generated / f"{name}.luau"
            path.write_text('local style_sheet = require("@src/instances/style_sheet")\n' + source + "\n")
            negatives.append(path)

        positives = [FIXTURES / "style_sheet.luau", ROOT / "src/instances/style_sheet.client.luau"]
        module = ROOT / "src/instances/style_sheet.luau"
        result = subprocess.run(
            [
                "luaulsp", "analyze", "--platform=roblox",
                "--definitions=types/globalTypes.d.luau", "--flag:LuauSolverV2=true",
                *map(str, [module, *positives, *negatives]),
            ],
            cwd=ROOT, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
        )
        errors = {}
        for line in result.stdout.splitlines():
            match = re.match(r"(.+?)\(\d+,\d+\): (?:TypeError|SyntaxError):", line)
            if match:
                path = (ROOT / match[1]).resolve()
                errors.setdefault(path, []).append(line)

        failed = False
        for path in [module, *positives]:
            if path in errors:
                failed = True
                print("\n".join(errors[path]))
        for path in negatives:
            if path not in errors:
                failed = True
                print(f"Expected a type error: {path.stem}")
        if result.returncode not in (0, 1) or not errors:
            failed = True
            print(result.stdout)
        if failed:
            raise SystemExit(1)
        unrelated = sum(len(lines) for path, lines in errors.items() if path not in {module, *positives, *negatives})
        print(f"Stylesheet types: {len(positives)} valid fixtures passed; {len(negatives)} invalid cases rejected.")
        if unrelated:
            print(f"Separate dependency diagnostics: {unrelated} (outside this stylesheet regression check).")


if __name__ == "__main__":
    main()

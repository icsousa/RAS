import { useEffect, useState } from "react";
import { Images } from "lucide-react";
import { ToolbarButton } from "./toolbar-button";
import { Input } from "../ui/input";
import { Label } from "../ui/label";
import { useCurrentImage, useProjectInfo, useUnsavedChanges } from "@/providers/project-provider";
import { isVideo } from "@/lib/projects";
import { ExtractFramesParams } from "@/lib/tool-types";

const defaults: ExtractFramesParams = { mode: "count", count: 6, interval: 2, format: "png" };

export default function ExtractFramesTool({ disabled }: { disabled: boolean }) {
  const [open, setOpen] = useState(false);
  const [params, setParams] = useState<ExtractFramesParams>(defaults);
  const project = useProjectInfo();
  const selected = useCurrentImage();
  const { setHasUnsavedChanges } = useUnsavedChanges();
  useEffect(() => {
    const saved = project.tools.find(t => t.procedure === "extract_frames");
    setParams(saved ? { ...defaults, ...(saved.params as ExtractFramesParams) } : defaults);
  }, [open, project.tools]);
  const update = (changes: Partial<ExtractFramesParams>) => {
    setParams(value => ({ ...value, ...changes }));
    setHasUnsavedChanges(true);
  };
  const valid = params.mode === "count"
    ? Number.isInteger(params.count) && params.count >= 1 && params.count <= 100
    : Number.isFinite(params.interval) && params.interval > 0;
  return (
    <ToolbarButton
      open={open} setOpen={setOpen} icon={Images} label="Extract frames"
      disabled={disabled} saveDisabled={!valid}
      previewDisabled={!valid || !isVideo(selected ?? undefined)}
      tool={{ procedure: "extract_frames", params }}
      onDefault={() => { setParams(defaults); setHasUnsavedChanges(false); }}
    >
      <div className="space-y-3 max-w-72">
        <p className="text-xs text-muted-foreground">
          Extract images from every video after all its edits. This is always the
          last step; new effects are inserted before it. Original images skip this step.
        </p>
        <Label htmlFor="frames-mode">Sampling</Label>
        <select id="frames-mode" className="w-full rounded border bg-background p-2 text-sm"
          value={params.mode} onChange={e => update({ mode: e.target.value as ExtractFramesParams["mode"] })}>
          <option value="count">Evenly spaced frames</option>
          <option value="interval">One frame every N seconds</option>
        </select>
        {params.mode === "count" ? <>
          <Label htmlFor="frames-count">Frames per video (1–100)</Label>
          <Input id="frames-count" type="number" min={1} max={100} step={1}
            value={Number.isNaN(params.count) ? "" : params.count}
            onChange={e => update({ count: e.target.valueAsNumber })} />
        </> : <>
          <Label htmlFor="frames-interval">Interval in seconds</Label>
          <Input id="frames-interval" type="number" min={0.01} step="any"
            value={Number.isNaN(params.interval) ? "" : params.interval}
            onChange={e => update({ interval: e.target.valueAsNumber })} />
        </>}
        <Label htmlFor="frames-format">Image format</Label>
        <select id="frames-format" className="w-full rounded border bg-background p-2 text-sm"
          value={params.format} onChange={e => update({ format: e.target.value as ExtractFramesParams["format"] })}>
          <option value="png">PNG</option><option value="jpeg">JPEG</option>
        </select>
        {!valid && <p role="alert" className="text-xs text-destructive">Enter a whole count from 1 to 100, or a positive interval.</p>}
        <p className="text-xs text-muted-foreground">
          Maximum 100 frames per video. Times refer to the edited video. Preview
          shows a contact sheet of up to six samples. Apply produces individual
          images instead of a video, ready to download separately or together in a ZIP.
        </p>
      </div>
    </ToolbarButton>
  );
}

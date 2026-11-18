"use client";

import { useState } from "react";
import {
  Dialog,
  DialogTrigger,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
  DialogFooter,
} from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Progress } from "@/components/ui/progress";
import ImageSubmissionArea from "../image-submission-area";
import { LoaderCircle, Plus } from "lucide-react";
import { useAddProjectImages } from "@/lib/mutations/projects";
import { createBlobUrlFromFile } from "@/lib/utils";
import { useProjectInfo } from "@/providers/project-provider";
import { useSession } from "@/providers/session-provider";
import { useToast } from "@/hooks/use-toast";
import { useSearchParams } from "next/navigation";
import { getErrorMessage } from "@/lib/error-messages";

export function AddImagesDialog() {
  const [open, setOpen] = useState(false);
  const [images, setImages] = useState<string[]>([]);
  const [imageFiles, setImageFiles] = useState<File[]>([]);
  // RNF-01: upload progress, so large videos do not look stuck
  const [progress, setProgress] = useState(0);
  const { toast } = useToast();

  const { _id: pid, version} = useProjectInfo();
  const session = useSession();

  // use the same owner/share as the project query, otherwise the cache key
  // differs and the new media only shows up after a page refresh
  const searchParams = useSearchParams();
  const ownerId = searchParams.get("owner") ?? session.user._id;
  const shareId = searchParams.get("share") ?? undefined;

  const addImages = useAddProjectImages(
    session.user._id,
    pid as string,
    session.token,
    ownerId,
    shareId,
  );

  function onDrop(files: File[]) {
    files.map(async (file) => {
      const url = await createBlobUrlFromFile(file);
      setImages((prevImages) => [...prevImages, url]);
    });
    setImageFiles(files);
  }

  function handleAdd() {
    setProgress(0);
    addImages.mutate(
      {
        images: imageFiles,
        projectVersion: version,
        onProgress: setProgress,
      },
      {
        onSuccess: () => {
          toast({
            title: "Media added successfully.",
          });
          setOpen(false);
        },
        onError: (error) => {
          const { title, description } = getErrorMessage("project-upload", error);
          toast({
            title,
            description,
            variant: "destructive",
          });
        },
      },
    );
  }

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        <Button className="inline-flex" variant="outline">
          <Plus /> Import
        </Button>
      </DialogTrigger>
      <DialogContent className="sm:max-w-[425px]">
        <DialogHeader>
          <DialogTitle>Import</DialogTitle>
          <DialogDescription>
            Add images or videos to your project.
          </DialogDescription>
        </DialogHeader>
        <ImageSubmissionArea onDrop={onDrop} />
        {addImages.isPending && (
          <div className="flex items-center gap-2 text-sm text-muted-foreground">
            <Progress value={progress} className="h-2" />
            <span className="w-24 text-right">
              {progress < 100 ? `Uploading ${progress}%` : "Processing…"}
            </span>
          </div>
        )}
        <DialogFooter>
          <Button
            onClick={handleAdd}
            disabled={images.length === 0}
            className="inline-flex items-center gap-1"
          >
            <span>Add</span>
            {addImages.isPending && (
              <LoaderCircle className="size-[1em] animate-spin" />
            )}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}

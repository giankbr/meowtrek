import { z } from "zod";

const stepCount = z.number().int().min(0).max(200_000);

export const Context = z.object({
  petName: z.string().trim().min(1).max(40),
  mood: z.string().trim().max(40).default("happy"),
  todaySteps: stepCount,
  goal: z.number().int().min(100).max(100_000),
  streak: z.number().int().min(0).max(10_000),
  weekSteps: z.array(stepCount).length(7),
  level: z.number().int().min(0).max(10_000),
  locale: z.string().trim().min(2).max(35),
});
export type Context = z.infer<typeof Context>;

export const ChatBody = z.object({
  messages: z
    .array(z.object({ role: z.enum(["user", "assistant"]), content: z.string().trim().min(1).max(2000) }))
    .min(1)
    .max(40)
    .refine((m) => m.at(-1)?.role === "user", "last message must be from user"),
  context: Context,
});

export const InsightBody = z.object({
  context: Context,
  last28Days: z.array(stepCount).length(28),
});

export const QuestsBody = z.object({
  context: Context,
  localHour: z.number().int().min(0).max(23).optional(),
});

// ~1.5 MB of base64 is plenty for a 1024px JPEG; the app downsizes before upload.
export const MealBody = z.object({
  context: Context,
  image: z.string().min(100).max(2_000_000).regex(/^[A-Za-z0-9+/=\s]+$/, "image must be base64"),
  mediaType: z.enum(["image/jpeg", "image/png", "image/webp"]).default("image/jpeg"),
});

export const Device = z.uuid();

// Shapes asked of the model; kept loose because ranges are enforced in code afterwards.
export const InsightOut = z.object({
  headline: z.string(),
  summary: z.string(),
  tips: z.array(z.string()),
  suggestedGoal: z.number().int(),
});

export const MealTag = z.enum(["veggies", "fruit", "protein", "grains", "dairy", "sweets", "fried", "drink", "homemade"]);
export const MealOut = z.object({
  isFood: z.boolean(),
  reaction: z.string(),
  tags: z.array(MealTag),
  balance: z.number().int(),
});

export const QuestKind = z.enum(["steps", "before", "after", "activeHours"]);
export const QuestsOut = z.object({
  quests: z.array(
    z.object({
      title: z.string(),
      detail: z.string(),
      kind: QuestKind,
      target: z.number().int(),
      hour: z.number().int().nullable(),
      reward: z.number().int(),
    }),
  ),
});
export type RawQuest = z.infer<typeof QuestsOut>["quests"][number];

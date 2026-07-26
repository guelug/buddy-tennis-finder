import { requireOptionalNativeModule } from "expo-modules-core";

export type LocalAIAvailability = {
  available: boolean;
  downloadable?: boolean;
  provider: "apple-intelligence" | "gemini-nano" | "fallback";
  reason?: string;
};

type MatchPointLocalAIModule = {
  getAvailability(): Promise<LocalAIAvailability>;
  generate(prompt: string): Promise<string>;
};

export default requireOptionalNativeModule<MatchPointLocalAIModule>("MatchPointLocalAI");

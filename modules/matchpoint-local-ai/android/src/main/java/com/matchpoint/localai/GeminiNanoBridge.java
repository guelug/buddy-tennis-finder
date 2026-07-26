package com.matchpoint.localai;

import androidx.annotation.NonNull;

import com.google.common.util.concurrent.FutureCallback;
import com.google.common.util.concurrent.Futures;
import com.google.common.util.concurrent.MoreExecutors;
import com.google.mlkit.genai.common.FeatureStatus;
import com.google.mlkit.genai.prompt.Candidate;
import com.google.mlkit.genai.prompt.GenerateContentResponse;
import com.google.mlkit.genai.prompt.Generation;
import com.google.mlkit.genai.prompt.java.GenerativeModelFutures;

import java.util.List;

public final class GeminiNanoBridge {
  public static final int AVAILABLE = FeatureStatus.AVAILABLE;
  public static final int DOWNLOADABLE = FeatureStatus.DOWNLOADABLE;
  public static final int DOWNLOADING = FeatureStatus.DOWNLOADING;

  private GeminiNanoBridge() {}

  public interface AvailabilityCallback {
    void onResult(int status);
    void onError(String message);
  }

  public interface GenerationCallback {
    void onResult(String text);
    void onError(String message);
  }

  private static GenerativeModelFutures model() {
    return GenerativeModelFutures.from(Generation.INSTANCE.getClient());
  }

  public static void checkAvailability(AvailabilityCallback callback) {
    Futures.addCallback(model().checkStatus(), new FutureCallback<Integer>() {
      @Override public void onSuccess(Integer status) {
        callback.onResult(status == null ? FeatureStatus.UNAVAILABLE : status);
      }

      @Override public void onFailure(@NonNull Throwable error) {
        callback.onError(error.getMessage() == null ? "Gemini Nano no está disponible" : error.getMessage());
      }
    }, MoreExecutors.directExecutor());
  }

  public static void generate(String prompt, GenerationCallback callback) {
    Futures.addCallback(model().generateContent(prompt), new FutureCallback<GenerateContentResponse>() {
      @Override public void onSuccess(GenerateContentResponse response) {
        List<Candidate> candidates = response == null ? null : response.getCandidates();
        String text = candidates == null || candidates.isEmpty() ? null : candidates.get(0).getText();
        if (text == null || text.trim().isEmpty()) callback.onError("El modelo no generó una respuesta");
        else callback.onResult(text);
      }

      @Override public void onFailure(@NonNull Throwable error) {
        callback.onError(error.getMessage() == null ? "No se pudo generar la respuesta" : error.getMessage());
      }
    }, MoreExecutors.directExecutor());
  }
}

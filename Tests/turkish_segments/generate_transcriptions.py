#!/usr/bin/env python3
"""
Generate transcriptions and translations for all Turkish audio files using faster-whisper
"""
import os
import json
from faster_whisper import WhisperModel

def main():
    # Use large-v2 model from cache (CTranslate2)
    model_path = os.path.expanduser("~/.cache/whisper-large-v2-ct2-float16")
    print(f"Loading Whisper large-v2 model from: {model_path}")
    model = WhisperModel(model_path, device="cpu", compute_type="auto")

    # Get all wav files
    wav_files = sorted([f for f in os.listdir('.') if f.endswith('.wav')])

    print(f"\nFound {len(wav_files)} audio files")
    print("=" * 70)

    results = {}

    for wav_file in wav_files:
        base_name = wav_file.replace('.wav', '')
        json_file = f"{base_name}.json"

        # Skip if JSON already exists
        if os.path.exists(json_file):
            print(f"✓ {wav_file} - JSON already exists, skipping")
            continue

        print(f"\n📝 Processing: {wav_file}")

        # Transcribe (Turkish)
        print("   Transcribing (Turkish)...")
        segments_tr, info_tr = model.transcribe(wav_file, language="tr", task="transcribe")
        transcription = " ".join([seg.text for seg in segments_tr]).strip()
        print(f"   Turkish: {transcription}")

        # Translate (Turkish → English)
        print("   Translating (Turkish → English)...")
        segments_en, info_en = model.transcribe(wav_file, language="tr", task="translate")
        translation = " ".join([seg.text for seg in segments_en]).strip()
        print(f"   English: {translation}")

        # Save to JSON
        data = {
            "seg_id": base_name,
            "text": transcription,
            "english": translation
        }

        with open(json_file, 'w', encoding='utf-8') as f:
            json.dump([data], f, indent=2, ensure_ascii=False)

        print(f"   ✅ Saved to {json_file}")

        results[base_name] = data

    print("\n" + "=" * 70)
    print(f"✅ Done! Generated transcriptions for {len(results)} new files")
    print(f"Total JSON files: {len([f for f in os.listdir('.') if f.endswith('.json')])}")

if __name__ == "__main__":
    main()

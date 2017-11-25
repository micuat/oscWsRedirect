class SoundPair {
  SoundObject soundCalm;
  SoundObject soundDist;

  SoundPair (SoundObject _soundCalm, SoundObject _soundDist) {
    soundCalm = _soundCalm;
    soundDist = _soundDist;
  }

  boolean isPlaying() {
    return soundCalm.ani.isPlaying() || soundDist.ani.isPlaying();
  }

  void fadeToCalm() {
    println("go to calm");
    soundCalm.fadeVolumeDelay(1);
    soundDist.fadeVolumeDelay(0);
  }

  void fadeToDist() {
    println("go to distract");
    soundCalm.fadeVolumeDelay(0);
    soundDist.fadeVolumeDelay(1);
  }
  
  void fadeOutAll() {
    soundCalm.fadeVolume(0);
    soundDist.fadeVolume(0);
  }
}
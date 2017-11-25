class SoundObject {
  float volume;
  int index;
  Ani ani;
  SoundPair parent;
  
  SoundObject(int _index) {
    index = _index;

    ani = new Ani(this, 0, "volume", 0);

    OscMessage m = new OscMessage("/inviso/volume");
    m.add(index);
    m.add(volume);
    queue.add(m);
  }

  void fadeVolume(float v) {
    ani.end();
    ani = new Ani(this, 3, "volume", v, Ani.EXPO_IN_OUT);
  }

  void fadeVolumeDelay(float v) {
    ani.end();
    ani = new Ani(this, 3, 2, "volume", v, Ani.EXPO_IN_OUT);
  }

  void update() {
    OscMessage m = new OscMessage("/inviso/volume");
    m.add(index);
    m.add(volume);
    queue.add(m);
  }
}
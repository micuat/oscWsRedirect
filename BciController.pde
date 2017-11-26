OscP5 oscPyP5;
NetAddress pyAddress;

class BciProgress {
  float x;
  float y;
  float w = 200;
  float h = 30;
  float progress;
  int index = 0;

  void setup(int _index) {
    progress = 0;
    index = _index;
  }

  void draw() {
    fill(255, 128);
    noStroke();
    rect(x, y, w, h);
    rect(x, y, map(progress, 0, 1, 0, w), h);
  }

  void mousePressed() {
    if (x <= mouseX && mouseX <= x + w
      && y <= mouseY && mouseY <= y + h) {
      OscMessage m;

      m = new OscMessage("/bci_art/svm/start/" + str(index));
      oscPyP5.send(m, pyAddress);
    }
  }
}

class BciController {
  float svmTarget = 0;
  float svmInterpolated = 0;
  float lowThreshold = 0.1;
  float highThreshold = 0.9;
  boolean didPassLow = false;
  boolean didPassHigh = false;
  int curNumPassed = 0;

  BciProgress p0 = new BciProgress();
  BciProgress p1 = new BciProgress();

  int score = 0;

  void setup() {
    p0.x = 100;
    p1.x = 100;
    p0.y = 100;
    p1.y = 150;
    p0.setup(0);
    p1.setup(1);

    oscPyP5 = new OscP5(this, 12200);
    pyAddress = new NetAddress("127.0.0.1", 12100);

    OscMessage m;
    m = new OscMessage("/bci_art/svm/reset");
    m.add(2);
    oscPyP5.send(m, pyAddress);
  }

  void draw() {
    if (p0.progress == 1 && p1.progress == 1) {
      float p = 0.985;
      svmInterpolated = svmInterpolated * p + (1-p) * svmTarget;
      if (!curPair.isPlaying()) {
        if (svmInterpolated < lowThreshold) {
          didPassLow = true;
          if (curNumPassed-1 >= 3 && numScenes > 1) {
          } else {
            curPair.fadeToDist();
          }
        }
        if (svmInterpolated > highThreshold) {
          didPassHigh = true;
          if (curNumPassed-1 >= 3 && numScenes > 1) {
          } else {
            curPair.fadeToCalm();
          }
        }
      }
      if (didPassLow && didPassHigh) {
        didPassLow = didPassHigh = false;
        curNumPassed++;

        if (curNumPassed >= 3 && numScenes > 1) {
          curNumPassed = 0;
          curPair.fadeOutAll();
          if (pairIterator.hasNext()) {
            curPair = pairIterator.next();
            println("go to next scene");
          } else {
            pairIterator = pairs.iterator();
            curPair = pairIterator.next();
            println("go to first scene");
          }
        }
      }
    }

    p0.draw();
    p1.draw();
    fill(255);
    text(str(score) + "%", 100, 50);
    float x = 100, y = 70, w = 200, h = 10;
    fill(255, 128);
    noStroke();
    rect(x, y, w, h);
    rect(x, y, map(svmInterpolated, 0, 1, 0, w), h);
  }

  void mousePressed() {
    p0.mousePressed();
    p1.mousePressed();
  }

  void keyPressed() {
    if (key == BACKSPACE) {
      OscMessage m;
      m = new OscMessage("/bci_art/svm/reset");
      m.add(2);
      oscPyP5.send(m, pyAddress);
    }
  }

  void oscEvent(OscMessage m) {
    if (m.addrPattern().equals("/bci_art/svm/progress/0")) {
      p0.progress = constrain((float)m.get(0).intValue() / m.get(1).intValue(), 0, 1);
    } else if (m.addrPattern().equals("/bci_art/svm/progress/1")) {
      p1.progress = constrain((float)m.get(0).intValue() / m.get(1).intValue(), 0, 1);
    } else if (m.addrPattern().equals("/bci_art/svm/prediction")) {
      svmTarget = m.get(0).floatValue();
    } else if (m.addrPattern().equals("/bci_art/svm/score")) {
      score = (int)(m.get(0).floatValue() * 100);
    }
  }
}
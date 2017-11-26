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
    if(x <= mouseX && mouseX <= x + w
      && y <= mouseY && mouseY <= y + h) {
      OscMessage m;
      
      m = new OscMessage("/bci_art/svm/start/" + str(index));
      oscPyP5.send(m, pyAddress);
    }
  }
}

class BciController {
  BciProgress p0 = new BciProgress();
  BciProgress p1 = new BciProgress();

  BciController() {
    p0.x = 100;
    p1.x = 100;
    p0.y = 100;
    p1.y = 150;
    p0.setup(0);
    p1.setup(1);
  }
  
  void draw() {
    p0.draw();
    p1.draw();
  }

  void mousePressed() {
    p0.mousePressed();
    p1.mousePressed();
  }

  void oscEvent(OscMessage m) {
    if(m.addrPattern().equals("/bci_art/svm/progress/0")) {
      p0.progress = constrain((float)m.get(0).intValue() / m.get(1).intValue(), 0, 1);
    }
    else if(m.addrPattern().equals("/bci_art/svm/progress/1")) {
      p1.progress = constrain((float)m.get(0).intValue() / m.get(1).intValue(), 0, 1);
    }
  }
}
import java.util.Iterator;
import java.util.Map;

import de.looksgood.ani.*;
import de.looksgood.ani.easing.*;
import netP5.*;
import oscP5.*;
import websockets.*;

OscP5 oscP5;
NetAddress pdAddress;

WebsocketServer ws;

ArrayList<OscMessage> queue = new ArrayList<OscMessage>();
ArrayList<OscMessage> queuePd = new ArrayList<OscMessage>();

int numScenes = 2;

Ani aniCalm, aniDist;

ArrayList<SoundObject> sounds = new ArrayList<SoundObject>();
ArrayList<SoundPair> pairs = new ArrayList<SoundPair>();
Iterator<SoundPair> pairIterator;
SoundPair curPair;

BciController bciController = new BciController();
HeadController headController = new HeadController();

void setup() {
  frameRate(30);
  size(600, 600);
  ws = new WebsocketServer(this, 8081, "/");

  oscP5 = new OscP5(this, 13000);
  pdAddress = new NetAddress("127.0.0.1",12555);
  
  Ani.init(this);

  bciController.setup();
  headController.setup();

  for (int i = 0; i < numScenes * 2; i++) {
    sounds.add(new SoundObject(i));
  }

  for (int i = 0; i < numScenes; i++) {
    pairs.add(new SoundPair(sounds.get(i * 2 + 0), sounds.get(i * 2 + 1)));
  }
  pairIterator = pairs.iterator();
  curPair = pairIterator.next();
}

void draw() {
  background(0);

  bciController.draw();
  headController.draw();

  for (SoundObject sound : sounds) {
    sound.update();
  }

  ArrayList<OscMessage> queueTmp = queue;
  queue = new ArrayList<OscMessage>();
  for (OscMessage m : queueTmp) {
    if (m != null)
      ws.sendMessage(m.getBytes());
  }

  queueTmp = queuePd;
  queuePd = new ArrayList<OscMessage>();
  for (OscMessage m : queueTmp) {
    if (m != null)
      oscP5.send(m, pdAddress);
  }
}

void webSocketServerEvent(String msg) {
}

void webSocketServerEvent(byte[] bytes, int offset, int length) {
  OscBinary b = new OscBinary(bytes);
  oscEvent(new OscMessage(b));
}

void oscEvent(OscMessage m) {
  String[] levels = m.addrPattern().split("/");

  if (levels.length <= 1) return; // [0] should be nothing

  if (levels[1].equals("bci_art")) {
    bciController.oscEvent(m);
  } else if (levels[1].equals("3dsoundone")) {
    headController.oscEvent(m);
  } else if (levels[1].equals("gyrosc")) {
    headController.oscEvent(m);
  } else if (levels[1].equals("subpac")) {
    if(levels[2].equals("gain")) {
      queuePd.add(m);
    }
  } else {
  }
}


void mousePressed() {
  bciController.mousePressed();
}

void keyPressed() {
  bciController.keyPressed();
}
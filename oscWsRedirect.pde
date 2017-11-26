import java.util.Iterator;

import de.looksgood.ani.*;
import de.looksgood.ani.easing.*;
import toxi.geom.*;
import netP5.*;
import oscP5.*;
import websockets.*;

OscP5 oscP5, oscPyP5;
NetAddress pyAddress;

WebsocketServer ws;

ArrayList<OscMessage> queue = new ArrayList<OscMessage>();

int numScenes = 2;

Ani aniCalm, aniDist;

ArrayList<SoundObject> sounds = new ArrayList<SoundObject>();
ArrayList<SoundPair> pairs = new ArrayList<SoundPair>();
Iterator<SoundPair> pairIterator;
SoundPair curPair;

Quaternion initQuaternion;

BciController bciController = new BciController();

void setup() {
  frameRate(30);
  size(600, 600);
  ws = new WebsocketServer(this, 8081, "/");

  oscP5 = new OscP5(this, 13000);
  oscPyP5 = new OscP5(this, 12200);
  pyAddress = new NetAddress("127.0.0.1", 12100);

  OscMessage m;
  m = new OscMessage("/bci_art/svm/reset");
  oscPyP5.send(m, pyAddress);

  Ani.init(this);

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

  for (SoundObject sound : sounds) {
    sound.update();
  }

  ArrayList<OscMessage> queueTmp = queue;
  queue = new ArrayList<OscMessage>();
  for (OscMessage m : queueTmp) {
    if (m != null)
      ws.sendMessage(m.getBytes());
  }
}

void webSocketServerEvent(String msg) {
}

void oscEvent(OscMessage m) {
  String[] levels = m.addrPattern().split("/");

  if (levels.length <= 1) return; // [0] should be nothing

  if (levels[1].equals("bci_art")) {
    bciController.oscEvent(m);
  } else if (m.addrPattern().equals("/3dsoundone/orientation")) {
    Quaternion q = new Quaternion(m.get(0).floatValue(), m.get(1).floatValue(), m.get(2).floatValue(), m.get(3).floatValue());

    if (initQuaternion == null) {
      Quaternion qYrot = Quaternion.createFromAxisAngle(new Vec3D(0, 1, 0), PI);
      Quaternion qZrot = Quaternion.createFromAxisAngle(new Vec3D(0, 0, 1), PI);

      initQuaternion = q.getConjugate().multiply(qYrot).multiply(qZrot);
    }

    q = q.multiply(initQuaternion);
    float[] euler = quaternionToEuler(q);

    OscMessage mr = new OscMessage("/inviso/head/rotation");
    mr.add(euler[0]);
    mr.add(euler[1]);
    mr.add(euler[2]);
    queue.add(mr);
  } else if (m.addrPattern().equals("/gyrosc/gyro")) {
    OscMessage mr = new OscMessage("/inviso/head/rotation");
    mr.add(-m.get(1).floatValue());
    mr.add(m.get(2).floatValue() + PI);
    mr.add(m.get(0).floatValue());
    queue.add(mr);
  } else {
  }
}

float[] quaternionToEuler(Quaternion q) {
  float[] qe = q.toArray();
  float[] euler = new float[3];
  euler[1] = -atan2(2 * (qe[0] * qe[1] + qe[2] * qe[3]), 1 - 2 * (qe[1] * qe[1] + qe[2] * qe[2]));
  euler[0] = -asin(2 * (qe[0] * qe[2] + qe[1] * qe[3]));
  euler[2] = atan2(2 * (qe[0] * qe[3] + qe[1] * qe[2]), 1 - 2 * (qe[2] * qe[2] + qe[3] * qe[3]));

  return euler;
}

void mousePressed() {
  bciController.mousePressed();
}

void keyPressed() {
  bciController.keyPressed();
}
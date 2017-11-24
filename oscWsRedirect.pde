import com.dhchoi.*;

import toxi.geom.*;

import netP5.*;
import oscP5.*;

import websockets.*;

OscP5 oscP5;

WebsocketServer ws;

CountdownTimer timer;

ArrayList<OscMessage> queue = new ArrayList<OscMessage>();

int oscCount = 0;
float interpolated = 0;
float target = 0;
float[] svmInterpolated = new float[128];
int svmIndex = 0;
float svmTarget = 0;

int numScenes = 2;
float lowThreshold = 0.1;
float highThreshold = 0.9;
int curScene = 0;
int fadeOutScene = 0;
boolean didPassLow = false;
boolean didPassHigh = false;
int curNumPassed = 0;

Quaternion initQuaternion;

void setup() {
  frameRate(30);
  size(600, 600);
  ws= new WebsocketServer(this, 8081, "/");

  oscP5 = new OscP5(this, 13000);

  for (int i = 0; i < svmInterpolated.length; i++) {
    svmInterpolated[i] = 0;
  }

  for (int i = 0; i < numScenes*2; i++) {
    OscMessage mr = new OscMessage("/inviso/volume");
    mr.add(i);
    mr.add(0);
    queue.add(mr);
  }
}

void draw() {
  background(0);

  float p = 0.985;
  int svmNextIndex = (svmIndex + 1) % svmInterpolated.length;
  svmInterpolated[svmNextIndex] = svmInterpolated[svmIndex] * p + (1-p) * svmTarget;

  if (svmInterpolated[svmNextIndex] < lowThreshold) didPassLow = true;
  if (svmInterpolated[svmNextIndex] > highThreshold) didPassHigh = true;
  if (didPassLow && didPassHigh) {
    didPassLow = didPassHigh = false;
    curNumPassed++;

    if (curNumPassed >= 2 && numScenes > 1) {
      fadeOutScene = curScene;
      timer = CountdownTimerService.getNewCountdownTimer(this).configure(100, 1000).start();

      curScene = (curScene + 1) % numScenes;
      println("go to scene " + curScene);
    }
  }

  int svmOldIndex = (svmIndex - 4 * 3 + svmInterpolated.length) % svmInterpolated.length;

  OscMessage mr = new OscMessage("/inviso/volume");
  mr.add(curScene * 2 + 1);
  mr.add(constrain(((1-svmInterpolated[svmOldIndex])-0.5)*3, 0, 1));
  queue.add(mr);
  mr = new OscMessage("/inviso/volume");
  mr.add(curScene * 2 + 0);
  mr.add(constrain((svmInterpolated[svmOldIndex]-0.5)*3, 0, 1));
  queue.add(mr);

  svmIndex = svmNextIndex;

  ArrayList<OscMessage> queueTmp = queue;
  queue = new ArrayList<OscMessage>();
  for (OscMessage m : queueTmp) {
    if (m != null)
      ws.sendMessage(m.getBytes());
  }
}

void onTickEvent(CountdownTimer t, long timeLeftUntilFinish) {
  OscMessage mr = new OscMessage("/inviso/volume");
  mr.add(fadeOutScene * 2 + 0);
  mr.add(timeLeftUntilFinish * 0.001);
  queue.add(mr);
  mr = new OscMessage("/inviso/volume");
  mr.add(fadeOutScene * 2 + 1);
  mr.add(timeLeftUntilFinish * 0.001);
  queue.add(mr);
}

void onFinishEvent(CountdownTimer t) {
  OscMessage mr = new OscMessage("/inviso/volume");
  mr.add(fadeOutScene * 2 + 0);
  mr.add(0);
  queue.add(mr);
  mr = new OscMessage("/inviso/volume");
  mr.add(fadeOutScene * 2 + 1);
  mr.add(0);
  queue.add(mr);
}

void webSocketServerEvent(String msg) {
}

void oscEvent(OscMessage m) {
  if (m.addrPattern().equals("/3dsoundone/orientation")) {
    Quaternion q = new Quaternion(m.get(0).floatValue(), m.get(1).floatValue(), m.get(2).floatValue(), m.get(3).floatValue());

    if (initQuaternion == null) {
      Quaternion qq = Quaternion.createFromAxisAngle(new Vec3D(0, 1, 0), PI);
      initQuaternion = q.getConjugate().multiply(qq);
      qq = Quaternion.createFromAxisAngle(new Vec3D(0, 0, 1), PI);
      initQuaternion = initQuaternion.multiply(qq);
    }

    q = q.multiply(initQuaternion);
    float[] qe = q.toArray();

    float ry = -atan2(2 * (qe[0] * qe[1] + qe[2] * qe[3]), 1 - 2 * (qe[1] * qe[1] + qe[2] * qe[2]));
    float rx = -asin(2 * (qe[0] * qe[2] + qe[1] * qe[3]));
    float rz = atan2(2 * (qe[0] * qe[3] + qe[1] * qe[2]), 1 - 2 * (qe[2] * qe[2] + qe[3] * qe[3]));
    OscMessage mr = new OscMessage("/inviso/head/rotation");
    mr.add(rx);
    mr.add(ry);
    mr.add(rz);
    queue.add(mr);
  } else if (m.addrPattern().equals("/gyrosc/gyro")) {
    OscMessage mr = new OscMessage("/inviso/head/rotation");
    mr.add(-m.get(1).floatValue());
    mr.add(m.get(2).floatValue() + PI);
    mr.add(m.get(0).floatValue());
    queue.add(mr);
  } else if (m.addrPattern().equals("/bci_art/svm/prediction")) {
    svmTarget = m.get(0).floatValue();
  } else {
  }
}

void mousePressed() {
}

void keyPressed() {
}
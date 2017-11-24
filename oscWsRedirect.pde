import com.dhchoi.*;

import toxi.geom.*;

import netP5.*;
import oscP5.*;

import websockets.*;

OscP5 oscP5;

WebsocketServer ws;
int now;
float x, y;

CountdownTimer timer;

ArrayList<OscMessage> queue = new ArrayList<OscMessage>();

int oscCount = 0;
float interpolated = 0;
float target = 0;
float[] svmInterpolated = new float[8];
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
  now=millis();
  x=0;
  y=0;

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
  ellipse(x, y, 10, 10);

  float p = 0.98;
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

  int svmOldIndex = (svmIndex - 1 + svmInterpolated.length) % svmInterpolated.length;

  OscMessage mr = new OscMessage("/inviso/volume");
  mr.add(curScene * 2 + 1);
  mr.add((1-svmInterpolated[svmOldIndex])*2);
  queue.add(mr);
  mr = new OscMessage("/inviso/volume");
  mr.add(curScene * 2 + 0);
  mr.add(svmInterpolated[svmOldIndex]);
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
}

void webSocketServerEvent(String msg) {
  println(msg);
  x=random(width);
  y=random(height);
}

/* incoming osc message are forwarded to the oscEvent method. */
void oscEvent(OscMessage m) {
  /* print the address pattern and the typetag of the received OscMessage */
  //print("### received an osc message.");
  //print(" addrpattern: "+m.addrPattern());
  //println(" typetag: "+m.typetag());

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
    //print(m.get(0).floatValue());
    OscMessage mr = new OscMessage("/inviso/head/rotation");
    mr.add(-m.get(1).floatValue());
    mr.add(m.get(2).floatValue() + PI);
    mr.add(m.get(0).floatValue());
    queue.add(mr);
  } else if (m.addrPattern().equals("/bci_art/svm/prediction")) {
    svmTarget = m.get(0).floatValue();
  } else if (m.addrPattern().equals("/muse/tsne")) {
    oscCount++;
    if (oscCount % 8 != 0) return;

    target = map(m.get(0).floatValue(), 0, 1, -PI, PI);
    OscMessage mr = new OscMessage("/inviso/object/add");
    float r = 200;
    float x = r * cos(target);
    float z = r * sin(target);
    mr.add(x);
    mr.add(0.0);
    mr.add(z);

    int tmplIndex = 0;
    if (m.get(2).intValue() < 80) tmplIndex = 1;
    else if (m.get(2).intValue() < 120) tmplIndex = 2;
    mr.add(tmplIndex);

    queue.add(mr);

    mr = new OscMessage("/inviso/volume/decrement");
    mr.add(0.2);
    queue.add(mr);

    //OscMessage mr = new OscMessage("/inviso/position");
    //float p = 0.9;
    //interpolated = interpolated * p + (1-p) * target;
    //float r = 400;
    //float x = r * cos(interpolated);
    //float z = r * sin(interpolated);
    //mr.add(x);
    ////mr.add(map(m.get(0).floatValue(), 0, 1, -500, 500));
    //mr.add(0.0);
    //mr.add(z);
    ////mr.add(map(m.get(1).floatValue(), 0, 1, -500, 500));
    //ws.sendMessage(mr.getBytes());
  } else {
    //ws.sendMessage(m.getBytes());
  }
}

void mousePressed() {
  OscMessage m = new OscMessage("/inviso/object/add");
  m.add(map(mouseX, 0, width, -300, 300));
  m.add(0.0);
  m.add(map(mouseY, 0, height, -300, 300));
  queue.add(m);

  m = new OscMessage("/inviso/volume/decrement");
  m.add(0.1);
  queue.add(m);
}

void mouseMoved() {
  //OscMessage m = new OscMessage("/inviso/volume");
  //m.add(0);
  //m.add(map(mouseX, 0, width, 0, 1));
  //queue.add(m);
  //m = new OscMessage("/inviso/volume");
  //m.add(1);
  //m.add(map(mouseX, 0, width, 1, 0));
  //queue.add(m);
}

void keyPressed() {
  if (key == '-') {
    OscMessage m = new OscMessage("/inviso/volume/decrement");
    m.add(0.1);
    queue.add(m);
  } else if (key == ' ') {
    OscMessage m = new OscMessage("/inviso/volume/all");
    m.add(random(1.0));
    queue.add(m);
  }
}
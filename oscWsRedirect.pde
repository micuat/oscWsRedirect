import de.looksgood.ani.*;
import de.looksgood.ani.easing.*;
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

float chCalm = 0;
float chDist = 0;

Ani aniCalm, aniDist;

Quaternion initQuaternion;

void setup() {
  frameRate(30);
  size(600, 600);
  ws = new WebsocketServer(this, 8081, "/");

  oscP5 = new OscP5(this, 13000);

  Ani.init(this);

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

  if (aniCalm == null || !aniCalm.isPlaying()) {
    if (svmInterpolated[svmNextIndex] < lowThreshold) {
      didPassLow = true;
      println("go to distract");
      aniCalm = new Ani(this, 1, 3, "chCalm", 0, Ani.EXPO_IN_OUT);
      aniDist = new Ani(this, 1, 3, "chDist", 1, Ani.EXPO_IN_OUT);
    }
    if (svmInterpolated[svmNextIndex] > highThreshold) {
      didPassHigh = true;
      println("go to calm");
      aniCalm = new Ani(this, 1, 3, "chCalm", 1, Ani.EXPO_IN_OUT);
      aniDist = new Ani(this, 1, 3, "chDist", 0, Ani.EXPO_IN_OUT);
    }
  }
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
  mr.add(curScene * 2 + 0);
  mr.add(chCalm);
  queue.add(mr);
  mr = new OscMessage("/inviso/volume");
  mr.add(curScene * 2 + 1);
  mr.add(chDist);
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
  } else if (m.addrPattern().equals("/bci_art/svm/prediction")) {
    svmTarget = m.get(0).floatValue();
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
}

void keyPressed() {
}
import toxi.geom.*;

class HeadController {
  Quaternion initQuaternion;

  void setup() {
  }

  void draw() {
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
}
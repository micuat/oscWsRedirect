public class OscBinary extends OscMessage {
  OscBinary(byte[] bytes) {
    super(new OscMessage(""));
    parseMessage(bytes);
  }
}
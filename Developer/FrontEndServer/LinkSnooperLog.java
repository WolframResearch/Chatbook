// Runs J/Link's LinkSnooper (com.wolfram.jlink.util.LinkSnooper), which relays all MathLink traffic between a front end
// and a kernel and prints every packet, with its output appended to a log file. `fe.py snoop` (FrontEndServer.wl, command
// "linkSnooper") starts it as the program of a front end evaluator, in Java's single-file source mode:
//
//     java -classpath JLink.jar LinkSnooperLog.java LOGFILE -nowindow -timestamps -pollinterval 1 -kernelname KERNEL
//
// The arguments after LOGFILE are LinkSnooper's (plus the link arguments the front end appends). Unlike LinkSnooper's
// own -logfile option, this does not also print everything to standard output (which ends up in the front end's
// output), appends instead of truncating the file when the kernel restarts, and logs J/Link errors too.
//
// LinkSnooper sleeps -pollinterval milliseconds between checks of its links. At 1 ms an idle LinkSnooper uses about 11%
// of a CPU core; at its default of 10 ms about 1%, but then each front end call from the kernel takes about 40 ms instead
// of 7 ms. So while there is traffic it polls at -pollinterval, and after a second without any it backs off to 10 ms.
// Traffic is noticed by what LinkSnooper prints, so it always prints all links (main, preemptive and service); lines of
// links that -links leaves out are dropped here.
//
// Secrets are redacted before anything is written (see Redactor): the license's activation key, password and machine
// ID, which the front end sends to every new kernel, and Wolfram Cloud authentication tokens. Their values are learned
// from the traffic itself, so they never have to be passed to this program. LinkSnooper options that would get around
// that (-logfile, -noinit, -feside, -kernelside) are refused.

import com.wolfram.jlink.util.LinkSnooper;

import java.io.FileOutputStream;
import java.io.IOException;
import java.io.OutputStream;
import java.io.PrintStream;
import java.lang.reflect.Field;
import java.nio.charset.StandardCharsets;
import java.nio.file.FileAlreadyExistsException;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.nio.file.attribute.PosixFilePermissions;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Comparator;
import java.util.Date;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

public class LinkSnooperLog {

    static final int IDLE_POLL_INTERVAL = 10;               // milliseconds (LinkSnooper's default)
    static final long IDLE_AFTER = 1_000_000_000L;          // nanoseconds without output
    static final String[] LINKS = {"main", "pre", "serv"};
    static final String[] REFUSED = {"-logfile", "-noinit", "-feside", "-kernelside"};

    static volatile long lastOutput = System.nanoTime();
    static volatile boolean idle = false;
    static Field pollField;                                 // LinkSnooper's private pollInterval, if accessible
    static LinkSnooper snooper;
    static int busyPollInterval;
    static Set<String> loggedLinks = new HashSet<>(Arrays.asList(LINKS));

    public static void main(String[] args) throws Exception {
        if (args.length < 1) {
            System.err.println("Usage: java -classpath JLink.jar LinkSnooperLog.java LOGFILE [LinkSnooper arguments]");
            System.exit(2);
        }
        // Only the owner may read the log, where the file system has POSIX permissions (an existing log keeps its
        // own; on Windows, the log is in the per-user temp directory):
        try {
            Files.createFile(Paths.get(args[0]),
                    PosixFilePermissions.asFileAttribute(PosixFilePermissions.fromString("rw-------")));
        } catch (FileAlreadyExistsException | UnsupportedOperationException e) {
            // append to it, or create it with the default permissions
        }
        FileOutputStream file = new FileOutputStream(args[0], true);
        PrintStream log = new RedactingStream(new ActivityStream(file));
        System.setOut(log);
        System.setErr(log);
        String stamp = "[" + new SimpleDateFormat("HH:mm:ss.SSS").format(new Date()) + "] LinkSnooperLog: ";
        log.println(stamp + "Java process " + ProcessHandle.current().pid());

        String[] snooperArgs = Arrays.copyOfRange(args, 1, args.length);
        for (String arg : snooperArgs) {
            for (String refused : REFUSED) {
                if (arg.equalsIgnoreCase(refused)) {
                    log.println(stamp + "the LinkSnooper option " + refused + " is not supported (secrets would not "
                            + "be redacted)");
                    System.exit(2);
                }
            }
        }
        // LinkSnooper prints all links, so that the redactor sees every packet and traffic on any link counts:
        for (int i = 0; i < snooperArgs.length - 1; i++) {
            if (snooperArgs[i].equalsIgnoreCase("-links")) {
                loggedLinks.clear();
                for (String link : LINKS) {
                    if (snooperArgs[i + 1].toLowerCase().contains(link)) {
                        loggedLinks.add(link);
                    }
                }
                snooperArgs[i + 1] = String.join(",", LINKS);
            }
        }
        busyPollInterval = pollInterval(snooperArgs);
        snooper = new LinkSnooper(snooperArgs); // connects to the front end and launches the kernel
        if (busyPollInterval < IDLE_POLL_INTERVAL) {
            adaptPolling();
        }
        snooper.start();
    }

    // The value of a LinkSnooper argument, or null:
    static String argument(String[] args, String name) {
        for (int i = 0; i < args.length - 1; i++) {
            if (args[i].equalsIgnoreCase(name)) {
                return args[i + 1];
            }
        }
        return null;
    }

    // The -pollinterval argument (LinkSnooper's default is 10 ms):
    static int pollInterval(String[] args) {
        try {
            String value = argument(args, "-pollinterval");
            return value == null ? IDLE_POLL_INTERVAL : Integer.parseInt(value);
        } catch (NumberFormatException e) {
            return IDLE_POLL_INTERVAL;
        }
    }

    static void adaptPolling() {
        try {
            pollField = LinkSnooper.class.getDeclaredField("pollInterval");
            pollField.setAccessible(true);
        } catch (ReflectiveOperationException | RuntimeException e) {
            pollField = null; // a different J/Link version: keep polling at -pollinterval
            return;
        }
        Thread monitor = new Thread(() -> {
            try {
                while (true) {
                    Thread.sleep(250);
                    if (!idle && System.nanoTime() - lastOutput > IDLE_AFTER) {
                        idle = true;
                        setPollInterval(IDLE_POLL_INTERVAL);
                    }
                }
            } catch (InterruptedException e) {
                // exit
            }
        }, "LinkSnooperLog idle monitor");
        monitor.setDaemon(true); // the JVM exits when LinkSnooper's relay thread ends
        monitor.start();
    }

    static void setPollInterval(int milliseconds) {
        try {
            pollField.setInt(snooper, milliseconds);
        } catch (IllegalAccessException | RuntimeException e) {
            // keep the current interval
        }
    }

    // LinkSnooper prints every packet it relays, so output means traffic: poll quickly again right away.
    static void activity() {
        lastOutput = System.nanoTime();
        if (idle && pollField != null) {
            idle = false;
            setPollInterval(busyPollInterval);
        }
    }

    // LinkSnooper prints each packet with println(String), one call per packet (whose text may contain newlines).
    static class RedactingStream extends PrintStream {
        RedactingStream(OutputStream out) {
            super(out, true, StandardCharsets.UTF_8);
        }

        @Override
        public void println(String line) {
            activity();
            Line parsed = null;
            String safe;
            try {
                parsed = Line.parse(line);
                safe = Redactor.redact(line, parsed);
            } catch (Throwable e) {
                // Neither let LinkSnooper's relay thread die nor write what might hold a secret:
                int stamp = line == null || !line.startsWith("[") ? -1 : line.indexOf("] ");
                safe = (stamp > 0 ? line.substring(0, stamp + 2) : "") + "LinkSnooperLog: a line of "
                        + (line == null ? 0 : line.length()) + " characters was left out (redaction failed: " + e + ")";
            }
            if (parsed != null && parsed.kind != Line.OTHER && !loggedLinks.contains(parsed.link)) {
                return; // a link that is not to be logged
            }
            super.println(safe);
        }
    }

    // A line as LinkSnooper prints it: "[12:34:56.789] " (with -timestamps), "-Pre-" or "-Serv-" for the preemptive
    // and service links, then "FE ---> K: " or "FE <--- K: " and the packet (Expr.toString), or a message line
    // ("****** Message ..."), or LinkSnooper's own text. Parsed by hand, like strings below: Java's regex engine
    // recurses for every character of a pattern like "(?:[^\"\\\\]|\\\\.)*", which overflows the stack on long lines.
    static final class Line {
        static final int OTHER = 0, MESSAGE = 1, PACKET = 2;
        final String link;      // "main", "pre" or "serv"
        final int kind;
        final boolean toKernel; // for packets: from the front end to the kernel
        final int packet;       // for packets: where the packet starts, after a "System`" context of its head

        Line(String link, int kind, boolean toKernel, int packet) {
            this.link = link;
            this.kind = kind;
            this.toKernel = toKernel;
            this.packet = packet;
        }

        static Line parse(String line) {
            if (line == null) {
                return null;
            }
            int at = 0;
            if (line.startsWith("[")) {
                int close = line.indexOf("] ");
                at = close < 0 ? 0 : close + 2;
            }
            at = skipSpaces(line, at);
            String link = "main";
            if (line.startsWith("-Serv-", at)) {
                link = "serv";
                at = skipSpaces(line, at + 6);
            } else if (line.startsWith("-Pre-", at)) {
                link = "pre";
                at = skipSpaces(line, at + 5);
            }
            if (line.startsWith("FE ---> K: ", at) || line.startsWith("FE <--- K: ", at)) {
                int packet = at + 11;
                if (line.startsWith("System`", packet)) {
                    packet += 7;
                }
                return new Line(link, PACKET, line.charAt(at + 3) == '-', packet);
            }
            return new Line(link, line.startsWith("****** Message", at) ? MESSAGE : OTHER, false, -1);
        }

        static int skipSpaces(String line, int at) {
            while (at < line.length() && line.charAt(at) == ' ') {
                at++;
            }
            return at;
        }

        // Whether the packet starts with this text (e.g. "ReturnPacket["):
        boolean is(String line, String start) {
            return kind == PACKET && line.startsWith(start, packet);
        }
    }

    // Replaces secrets in the log by "<redacted NAME>". A value is learned when it shows up where it is known to be a
    // secret, and from then on redacted wherever it appears:
    //  - the activation key, password and machine ID: the string values (or lists of strings) of each
    //    Rule["ActivationKey", ...], Rule["Password", ...] etc. in any reply of the front end to the kernel, such as
    //    the license's activation record, which the front end sends to every kernel it starts before anything else
    //    could show them;
    //  - Wolfram Cloud authentication tokens: the strings in the front end's reply to the kernel's
    //    CallPacket[FrontEnd`WolframCloud`GetAuthentication[]] (the ReturnPacket on the same link that is not part of
    //    an evaluation or call nested in between), the long strings in the kernel's
    //    CallPacket[FrontEnd`WolframCloud`ConnectionEstablished[url, id, name, uuid, {token}]] (made by a kernel that
    //    connected by itself), and strings shaped like tokens (Compress output, "1:...") in its other
    //    FrontEnd`WolframCloud` calls and in whatever the front end sends while a GetAuthentication call is pending.
    // Strings shaped like activation keys and machine IDs are redacted even if they were never learned (e.g. by a
    // kernel that does not ask the front end for the activation record).
    static class Redactor {
        static final String[] RECORD_KEYS = {"ActivationKey", "Password", "MachineID", "LicenseID"};
        static final int MIN_SECRET = 6;   // shorter values would redact unrelated text
        static final int MIN_TOKEN = 64;   // long strings in ConnectionEstablished are tokens, not names or URLs
        // The activation record has a few values; many more Rule["Password", ...] etc. are user data (e.g. a table in a
        // notebook), and each learned value makes every line slower to redact:
        static final int MAX_RECORD_VALUES = 32;
        // Shapes of activation keys and machine IDs ('9': a digit, 'A': a digit or capital letter); both 16 long:
        static final String[][] SHAPES = {{"9999-9999-AAAAAA", "ActivationKey"}, {"9999-99999-99999", "MachineID"}};

        static final Map<String, String> secrets = new HashMap<>();  // value -> name
        static List<String> longestFirst = new ArrayList<>();        // the values, so that no part of one is replaced
        static final Map<String, Integer> awaitingToken = new HashMap<>(); // link -> nesting since GetAuthentication
        static int recordValues = 0;                                       // values learned by learnRuleValues

        static synchronized String redact(String line, Line parsed) {
            if (line == null) {
                return null;
            }
            if (parsed != null && parsed.kind == Line.PACKET) {
                learnFrom(line, parsed);
            }
            for (String secret : longestFirst) {
                if (line.contains(secret)) {
                    line = line.replace(secret, "<redacted " + secrets.get(secret) + ">");
                }
            }
            return redactShapes(line);
        }

        // Replaces strings shaped like SHAPES that are not part of a longer word (scanned by hand: regular expressions
        // with lookarounds take seconds on the largest packets).
        static String redactShapes(String line) {
            StringBuilder out = null;
            int copied = 0, n = line.length();
            for (int i = 0; i + 16 <= n; i++) {
                if (!isDigit(line.charAt(i)) || i > 0 && isWordOrDash(line.charAt(i - 1))
                        || i + 16 < n && isWordOrDash(line.charAt(i + 16))) {
                    continue;
                }
                for (String[] shape : SHAPES) {
                    if (shaped(line, i, shape[0])) {
                        if (out == null) {
                            out = new StringBuilder(n);
                        }
                        out.append(line, copied, i).append("<redacted ").append(shape[1]).append('>');
                        copied = i + 16;
                        i += 15;
                        break;
                    }
                }
            }
            return out == null ? line : out.append(line, copied, n).toString();
        }

        static boolean shaped(String line, int at, String shape) {
            for (int k = 0; k < shape.length(); k++) {
                char c = line.charAt(at + k), s = shape.charAt(k);
                if (s == '9' ? !isDigit(c) : s == 'A' ? !(isDigit(c) || c >= 'A' && c <= 'Z') : c != s) {
                    return false;
                }
            }
            return true;
        }

        static boolean isDigit(char c) {
            return c >= '0' && c <= '9';
        }

        static boolean isWordOrDash(char c) {
            return isDigit(c) || c >= 'A' && c <= 'Z' || c >= 'a' && c <= 'z' || c == '-';
        }

        static void learnFrom(String line, Line p) {
            if (p.toKernel && p.is(line, "ReturnPacket[") && line.contains("Rule[\"")) {
                for (String key : RECORD_KEYS) {
                    learnRuleValues(line, key);
                }
            }
            Integer depth = awaitingToken.get(p.link);
            if (depth != null) {
                if (p.toKernel) {
                    learnStrings(line, "1:", MIN_TOKEN);
                }
                if (p.is(line, "ReturnPacket[")) {
                    if (depth == 0) {
                        awaitingToken.remove(p.link);
                        if (p.toKernel) {
                            learnStrings(line, "", MIN_SECRET); // the reply
                        }
                    } else {
                        awaitingToken.put(p.link, depth - 1);
                    }
                } else if (p.is(line, p.toKernel ? "EvaluatePacket[" : "CallPacket[")) {
                    awaitingToken.put(p.link, depth + 1);
                }
            }
            if (!p.toKernel && p.is(line, "CallPacket[FrontEnd`WolframCloud`")) {
                if (p.is(line, "CallPacket[FrontEnd`WolframCloud`GetAuthentication[")) {
                    awaitingToken.put(p.link, 0);
                } else if (p.is(line, "CallPacket[FrontEnd`WolframCloud`ConnectionEstablished[")) {
                    learnStrings(line, "", MIN_TOKEN);
                } else {
                    learnStrings(line, "1:", MIN_TOKEN);
                }
            }
        }

        // Learns the values of Rule["KEY", "..."], and the strings of list values: Rule["KEY", {"...", "..."}] (up to
        // the first element that is not a string).
        static void learnRuleValues(String line, String key) {
            String rule = "Rule[\"" + key + "\", ";
            for (int at = line.indexOf(rule); at >= 0; at = line.indexOf(rule, at + 1)) {
                int start = at + rule.length();
                boolean list = line.startsWith("{", start);
                if (list) {
                    start++;
                }
                while (line.startsWith("\"", start)) {
                    int end = stringEnd(line, start);
                    if (end < 0) {
                        break;
                    }
                    String value = line.substring(start + 1, end - 1);
                    if (recordValues < MAX_RECORD_VALUES && learn(value, key, MIN_SECRET)) {
                        recordValues++;
                    }
                    if (!list || !line.startsWith(", ", end)) {
                        break;
                    }
                    start = end + 2;
                }
            }
        }

        // Learns the strings with this prefix and at least this length; with the prefix "1:", only those that are
        // shaped like Compress output ("1:" and base64), as the Wolfram Cloud tokens are.
        static void learnStrings(String line, String prefix, int minLength) {
            for (int start = line.indexOf('"'); start >= 0; start = line.indexOf('"', start)) {
                int end = stringEnd(line, start);
                if (end < 0) {
                    break;
                }
                String value = line.substring(start + 1, end - 1);
                if (value.startsWith(prefix) && (!prefix.equals("1:") || base64(value, 2))) {
                    learn(value, "CloudAuthentication", minLength);
                }
                start = end;
            }
        }

        static boolean base64(String value, int from) {
            for (int i = from; i < value.length(); i++) {
                char c = value.charAt(i);
                if (!(Character.isLetterOrDigit(c) && c < 128 || c == '+' || c == '/' || c == '=')) {
                    return false;
                }
            }
            return true;
        }

        // The end (after the closing quote) of the string literal that starts with the quote at `start`, or -1.
        // Expr.toString writes strings in quotes, with \" and \\ inside.
        static int stringEnd(String line, int start) {
            for (int i = start + 1; i < line.length(); i++) {
                char c = line.charAt(i);
                if (c == '\\') {
                    i++;
                } else if (c == '"') {
                    return i + 1;
                }
            }
            return -1;
        }

        // Whether the value is new:
        static boolean learn(String value, String name, int minLength) {
            if (value.length() >= minLength && !value.contains("<redacted ") && !secrets.containsKey(value)) {
                secrets.put(value, name);
                longestFirst = new ArrayList<>(secrets.keySet());
                longestFirst.sort(Comparator.comparingInt(String::length).reversed());
                return true;
            }
            return false;
        }
    }

    static class ActivityStream extends OutputStream {
        private final OutputStream out;

        ActivityStream(OutputStream out) {
            this.out = out;
        }

        @Override
        public void write(int b) throws IOException {
            activity();
            out.write(b);
        }

        @Override
        public void write(byte[] b, int off, int len) throws IOException {
            activity();
            out.write(b, off, len);
        }

        @Override
        public void flush() throws IOException {
            out.flush();
        }

        @Override
        public void close() throws IOException {
            out.close();
        }
    }
}

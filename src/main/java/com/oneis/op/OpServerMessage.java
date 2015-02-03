/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package com.oneis.op;

import java.io.Serializable;

public class OpServerMessage implements Serializable {
    static public class Authenticate extends OpServerMessage {
        public int workerNumber;
        public String authenticationToken;
    }

    static public class AuthenticateAccepted extends OpServerMessage {
        public boolean accepted;
    }

    static public class DoOperation extends OpServerMessage {
        public Operation operation;
    }

    static public class AcknowledgeOperation extends OpServerMessage {
        public boolean ok;
    }

    static public class DoneOperation extends OpServerMessage {
        public Operation resultOperation;
        public Exception resultException;
        public boolean willExit;    // process intends to exit (and will be restarted)
    }
}

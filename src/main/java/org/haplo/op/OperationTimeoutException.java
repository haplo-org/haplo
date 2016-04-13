/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.op;

public class OperationTimeoutException extends Exception {
    private Operation operation;

    public OperationTimeoutException(Operation operation, String message) {
        super(message);
        this.operation = operation;
    }

    public OperationTimeoutException(Operation operation, String message, Throwable throwable) {
        super(message, throwable);
        this.operation = operation;
    }

    public Operation getOperation() {
        return this.operation;
    }
}

/*
 * Copyright 2019 Arcus Project
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
package com.iris.agent.zw;

import java.util.HashSet;
import java.util.Set;

import com.iris.agent.zw.code.Decoded;
import com.iris.agent.zw.code.ZCmd;
import com.iris.agent.zw.code.ZWCmdHandler;

/**
 * 
 * Handles routing of ZWave messages to handlers.
 * 
 * @author Erik Larson
 */
public class ZWRouter {
   public final static ZWRouter INSTANCE = new ZWRouter();
   
   private final Set<ZWCmdHandler> handlers = new HashSet<ZWCmdHandler>();
   
   private ZWRouter() { };
   
   public void registerCmdHandler(ZWCmdHandler handler) {
      handlers.add(handler);
   }
   
   public void unregisterCmdHandler(ZWCmdHandler handler) {
      handlers.remove(handler);
   }
   
   /**
    * If the incoming message is a ZWave Command or contains ZWave Commands, then iterate through
    * the commands and send to all registered handlers. 
    * 
    * @param ZWData
    */
   public void route(ZWData data) {
      if (data.getDecoded().type() == Decoded.Type.CMD) {
         ZCmd zcmd = data.getDecoded().decoded();
         
         if (zcmd != null) {
            handlers.forEach(h -> h.processCmd(data.getNodeId(), zcmd));             
         }
      }
   }
}

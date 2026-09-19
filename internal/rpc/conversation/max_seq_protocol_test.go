// Copyright © 2026 OpenIM. All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package conversation

import (
	"testing"

	pbconversation "github.com/openimsdk/protocol/conversation"
)

func TestSetConversationMaxSeqReqAllowsZero(t *testing.T) {
	valid := &pbconversation.SetConversationMaxSeqReq{
		ConversationID: "sg_protocol_contract",
		OwnerUserID:    []string{"protocol-contract-user"},
		MaxSeq:         0,
	}
	if err := valid.Check(); err != nil {
		t.Fatalf("maxSeq=0 必须允许，群成员加入时会用它表示从当前位点同步: %v", err)
	}

	invalid := &pbconversation.SetConversationMaxSeqReq{
		ConversationID: "sg_protocol_contract",
		OwnerUserID:    []string{"protocol-contract-user"},
		MaxSeq:         -1,
	}
	if err := invalid.Check(); err == nil {
		t.Fatal("负数 maxSeq 必须被拒绝")
	}
}

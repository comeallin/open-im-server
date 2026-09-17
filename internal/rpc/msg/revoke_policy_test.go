package msg

import (
	"testing"
	"time"

	"github.com/openimsdk/protocol/sdkws"
)

func TestValidateManagedRevoke(t *testing.T) {
	now := time.UnixMilli(1_000_000)
	tests := []struct {
		name    string
		userID  string
		message *sdkws.MsgData
		wantErr bool
	}{
		{name: "作者在窗口内撤回", userID: "author", message: &sdkws.MsgData{SendID: "author", SendTime: now.Add(-119 * time.Second).UnixMilli()}},
		{name: "非作者不能撤回", userID: "owner", message: &sdkws.MsgData{SendID: "author", SendTime: now.UnixMilli()}, wantErr: true},
		{name: "超过窗口不能撤回", userID: "author", message: &sdkws.MsgData{SendID: "author", SendTime: now.Add(-121 * time.Second).UnixMilli()}, wantErr: true},
		{name: "未来时间不能绕过窗口", userID: "author", message: &sdkws.MsgData{SendID: "author", SendTime: now.Add(time.Second).UnixMilli()}, wantErr: true},
		{name: "空消息拒绝", userID: "author", wantErr: true},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := validateManagedRevoke(tt.userID, tt.message, now)
			if (err != nil) != tt.wantErr {
				t.Fatalf("validateManagedRevoke() error = %v, wantErr %v", err, tt.wantErr)
			}
		})
	}
}

package msg

import "testing"

func TestValidateReadPosition(t *testing.T) {
	tests := []struct {
		name               string
		current, requested int64
		max                int64
		wantAdvance        bool
		wantErr            bool
	}{
		{name: "前进", current: 3, requested: 5, max: 8, wantAdvance: true},
		{name: "重复", current: 5, requested: 5, max: 8},
		{name: "拒绝回退", current: 5, requested: 3, max: 8, wantErr: true},
		{name: "拒绝越界", current: 5, requested: 9, max: 8, wantErr: true},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			advance, err := validateReadPosition(tt.current, tt.requested, tt.max)
			if advance != tt.wantAdvance || (err != nil) != tt.wantErr {
				t.Fatalf("validateReadPosition() = (%v, %v), want (%v, err=%v)", advance, err, tt.wantAdvance, tt.wantErr)
			}
		})
	}
}

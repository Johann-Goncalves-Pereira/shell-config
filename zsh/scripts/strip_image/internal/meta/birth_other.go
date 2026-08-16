//go:build !darwin

package meta

import (
	"os"
	"time"
)

func birthTime(os.FileInfo) time.Time {
	return time.Time{}
}

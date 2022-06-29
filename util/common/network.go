package common

import (
	"io/ioutil"
	"net/http"
)

func GetMyIpAddr() string {
	resp, err := http.Get("https://api.ip.sb/ip")
	if err != nil {
		resp, _ = http.Get("https://api64.ipify.org")
	}
	defer resp.Body.Close()
	s, _ := ioutil.ReadAll(resp.Body)
	return string(s)
}

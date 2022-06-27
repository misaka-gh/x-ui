package common

import (
	"io/ioutil"
	"net/http"
)

func GetMyIpAddr() string {
	resp, err := http.Get("https://api.ip.sb/ip")
	if err != nil {
		resp, _ = http.Get("http://icanhazip.com")
	}
	defer resp.Body.Close()
	s, _ := ioutil.ReadAll(resp.Body)
	return string(s)
}

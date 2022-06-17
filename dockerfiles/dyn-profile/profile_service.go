// Copyright (C) 2021 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause

package main

import (
  "encoding/json"
  "fmt"
  "io/ioutil"
  "log"
  "net/http"
  "os"
  "os/exec"
  "strings"
  "bufio"
  "errors"
)

type Hardwares struct {
  Hardwares []Hardware `json:"hardwares"`
}

type Hardware struct {
  ID          string `json:"id"`
  CPU         string `json:"cpu"`
  MacAddress  string `json:"mac"`
  Profile     string `json:"profile"`
  ProfileUrl  string `json:"profileUrl"`
  BaseBranch  string `json:"baseprofileUrl"`
  BootUrl     string `json:"booturl"`
  KernelArgs  string `json:"kernelargs"`
}

var hardwares Hardwares
var ipAddr string
var profileDir string
var profileUser string
var profileToken string


func httpHandler(w http.ResponseWriter, r *http.Request) {
  var hw Hardware
  var js []byte
  w.Header().Set("Content-Type", "application/json")
  switch r.Method {
  case "GET":
    getHardwareStruct()
    js, _ = json.Marshal(&hardwares)
    w.WriteHeader(http.StatusOK)
    w.Write(js)
  case "POST":
    var stat int = 404
    getHardwareStruct()
    json.NewDecoder(r.Body).Decode(&hw)
    for _, v := range hardwares.Hardwares {
      if v.MacAddress == hw.MacAddress {
	data := make(map[string]interface{})
	data["url"] = v.BootUrl
	data["basebranch"] = v.BaseBranch
	data["kernelParams"] = v.KernelArgs
	js, _ = json.Marshal(data)
	stat = http.StatusOK
      }
    }
    w.WriteHeader(stat)
    if stat == http.StatusOK {
      w.Write(js)
    }
  }
}

func getHardwareInfoFile() (error) {

  var err error
  if strings.HasPrefix(profileDir,"http") {
    cmd := exec.Command("curl","-L", "--user", profileUser+":"+profileToken, profileDir, "-o", "/data/hardware.json")
    err = cmd.Run()
  } else if strings.HasPrefix(profileDir,"/") {
    cmd := exec.Command("cp", profileDir, "/data/hardware.json")
    err = cmd.Run()
  } else {
    log.Println("Invalid location for downloading hardware profile information")
    err = errors.New("Invalid download location for hardwre profiles!")
  }

  return err
}

func getHardwareStruct() (error) {
  err := getHardwareInfoFile()
  if err != nil {
    return err
  }
  jsonFile, err := os.Open("/data/hardware.json")
  if err != nil {
    log.Println("Error opening json file:" +err.Error())
    return err
  }
  byteValue, _ := ioutil.ReadAll(jsonFile)
  if err := json.Unmarshal(byteValue, &hardwares); err != nil {
    log.Println("Error getting json details:" +err.Error())
    return err
  }
  defer jsonFile.Close()

  baseUrl := "http://" +ipAddr + "/profile/"
  for i := 0; i < len(hardwares.Hardwares); i++ {
    hardwares.Hardwares[i].ProfileUrl = baseUrl + hardwares.Hardwares[i].Profile
    hardwares.Hardwares[i].BootUrl = hardwares.Hardwares[i].ProfileUrl  + "/bootstrap.sh"
    cmd := exec.Command("wget", "--spider", "--no-proxy",  hardwares.Hardwares[i].BootUrl)
    err := cmd.Run()
    if err != nil {
      log.Println("no profile " + hardwares.Hardwares[i].BootUrl + " found on server")
      return err
    }
    cmd = exec.Command("wget", "--spider", "--no-proxy",  hardwares.Hardwares[i].ProfileUrl+"_base/pre.sh")
    err = cmd.Run()
    if err != nil {
      log.Println("no base branch for " + hardwares.Hardwares[i].ProfileUrl + " found on server, leave that empty")
      return  err
    } else {
       hardwares.Hardwares[i].BaseBranch = hardwares.Hardwares[i].ProfileUrl+"_base"
    }
    confFileUrl := hardwares.Hardwares[i].ProfileUrl+"/conf/config.yml"
    fmt.Println("ConfigFileUrl: "+confFileUrl)
    cmd = exec.Command("wget", "--no-proxy", confFileUrl)
    err = cmd.Run()
    if err != nil {
      log.Println("config file not found for profile " + hardwares.Hardwares[i].Profile)
      return err
    }
    confFile, err := os.Open("config.yml")
    if err != nil {
      log.Println("error opening config file")
      return err
    }
    defer confFile.Close()
    scanner := bufio.NewScanner(confFile)
    for scanner.Scan() {
      line := string(scanner.Text())
      if strings.HasPrefix(line,"kernel_arguments:") == true {
	hardwares.Hardwares[i].KernelArgs = strings.ReplaceAll(line,"kernel_arguments:","")
	log.Println("Kernel args:" + hardwares.Hardwares[i].KernelArgs)
      }
    }
    cmd = exec.Command("rm","config.yml")
    cmd.Run()
  }
  return nil
}

func main() {
  ipAddr = os.Getenv("host_ip")
  profileDir = os.Getenv("dyn_url")
  profileUser = os.Getenv("dyn_url_user")
  profileToken = os.Getenv("dyn_url_token")

  log.Println("profileDir: "+profileDir)
  log.Println("profileUser: "+profileUser)
  log.Println("profileToken: "+profileToken)
  log.Println("hostip: "+ipAddr)

  http.HandleFunc("/hardwares", httpHandler)
  log.Println("Listening on localhost:8080")
  log.Println(http.ListenAndServe(":8080", nil))
}

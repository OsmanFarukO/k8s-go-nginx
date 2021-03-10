package main

import (
"fmt"
"net/http"
)

func main() {


http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
    name := r.URL.Path[len("/"):]
    fmt.Fprintf(w, "Hello Turkai from ssssssssssssssssssss%s\n", name)
})

http.ListenAndServe(":11130", nil)
}

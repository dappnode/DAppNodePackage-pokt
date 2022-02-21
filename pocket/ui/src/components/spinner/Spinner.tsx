import React from "react";
import { Spinner as Loader } from "react-bootstrap";
import "./Spinner.scss";

export default function Spinner({ overlay }: { overlay: boolean }) {
  return <>{overlay ? <Loader className="spinner-overlay" animation="border" /> : <Loader animation="border" />}</>;
}

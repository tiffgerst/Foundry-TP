import { Header } from "./components/Header";
import Navbar from "./components/Navbar";
import styles from "./app.module.scss";
import Particles from "react-particles";
import { loadFull } from "tsparticles";
import { useCallback } from "react";

function App() {
  return (
    <div className={styles.App}>
      <Navbar />
      <canvas id="Matrix"></canvas>
      <script src="./index.js"></script>
    </div>
  );
}

export default App;

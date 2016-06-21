import processing.serial.*;
import controlP5.*;
import processing.opengl.*;

Serial myPort;
ControlP5 cp5;

/* GUI KOMPONENTE */
Slider treshSlider,mixtureSlider;
Toggle toggleRezim;

/* PROMENLJIVE */
float acc[];
float gyro[];

float ugaoY, ugaoY_last, ugaoX, ugaoX_last, ugaoX_rad, ugaoY_rad,ugaoZ;
float tresh_zero, tresh_angle;

String rezimRada="Akcelerometar";

boolean rezim=true;

/* KOMPLEMENTARNI FILTAR */
float accel_sensitivity = 8192.0; //Vrednost 0.5G
float gyro_sensitivity = 65.536;  //Puna skala
float M_PI = 3.14159265359;       //Pi
float mesavina=0.98;

/* TEKSTURE I METODA ZA CRTANJE KOCKE */
PImage front, back, top, bottom, left, right;

void TexturedCube(float ax, float ay) {
  hint(ENABLE_DEPTH_TEST);

  translate(width/2, height/2, 0);
  rotateY(ax);
  rotateX(ay);
  rotateZ(ugaoZ);
  scale(90);

  //Ispred

  beginShape(QUADS);
  texture(front);

  vertex(-1, -1, 1, 0, 0);
  vertex( 1, -1, 1, 1, 0);
  vertex( 1, 1, 1, 1, 1);
  vertex(-1, 1, 1, 0, 1);
  endShape();

  //Pozadi

  beginShape(QUADS);
  texture(back);

  vertex( 1, -1, -1, 0, 0);
  vertex(-1, -1, -1, 1, 0);
  vertex(-1, 1, -1, 1, 1);
  vertex( 1, 1, -1, 0, 1);
  endShape();

  //Dole

  beginShape(QUADS);
  texture(bottom);

  vertex(-1, 1, 1, 0, 0);
  vertex( 1, 1, 1, 1, 0);
  vertex( 1, 1, -1, 1, 1);
  vertex(-1, 1, -1, 0, 1);
  endShape();

  //Gore

  beginShape(QUADS);
  texture(top);

  vertex(-1, -1, -1, 0, 0);
  vertex( 1, -1, -1, 1, 0);
  vertex( 1, -1, 1, 1, 1);
  vertex(-1, -1, 1, 0, 1);
  endShape();

  //Desno
  beginShape(QUADS);
  texture(right);

  vertex( 1, -1, 1, 0, 0);
  vertex( 1, -1, -1, 1, 0);
  vertex( 1, 1, -1, 1, 1);
  vertex( 1, 1, 1, 0, 1);
  endShape();

  //Levo
  beginShape(QUADS);
  texture(left);

  vertex(-1, -1, -1, 0, 0);
  vertex(-1, -1, 1, 1, 0);
  vertex(-1, 1, 1, 1, 1);
  vertex(-1, 1, -1, 0, 1);

  endShape();
  hint(DISABLE_DEPTH_TEST);
  camera();
}

void setup()
{
  size(800, 600, P3D);
  String portName = Serial.list()[0];
  print("Port: "+Serial.list()[0]);
  myPort = new Serial(this, portName, 57600);

  //Promenljive
  ugaoY=0;
  ugaoY_last=0;
  ugaoX=0;
  ugaoX_last=0;

  tresh_zero=3.0;
  tresh_angle=1.5;

  acc = new float[3];
  gyro = new float[3];

  acc[0]=0;
  acc[1]=0;
  acc[2]=0;

  gyro[0]=0;
  gyro[1]=0;
  gyro[2]=0;
  
  ugaoZ=0;

  //GUI kontrole
  cp5 = new ControlP5(this);

  //name,min,max,default value (float),x,y,width,height
  treshSlider = cp5.addSlider("trangle_slider", 0, 10, tresh_angle, 25, 70, 25, 150);
  treshSlider.setLabel("Treshold");
  
  mixtureSlider = cp5.addSlider("mixture_slider",0,1.0,mesavina,25, 70, 25, 150);
  mixtureSlider.setLabel("Ziroskop: "+round(mesavina*100)+"%\n"+"Akcelerometar: "+round((1.0-mesavina)*100)+" %");
  mixtureSlider.hide();
  
  toggleRezim = cp5.addToggle("toggle_rezim")
     .setPosition(25,25)
     .setSize(50,20)
     .setValue(true)
     .setLabel("Rezim rada")
     .setMode(ControlP5.SWITCH)
     ;

  //Tekst
  textFont(createFont("", 16));

  //Kocka teksture
  front = loadImage("front_texture.jpg");
  back = loadImage("back_texture.jpg");
  top = loadImage("top_texture.jpg");
  bottom = loadImage("bottom_texture.jpg");
  left = loadImage("left_texture.jpg");
  right = loadImage("right_texture.jpg");

  textureMode(NORMAL);
  fill(255);
  stroke(color(44, 48, 32));
}


void draw()
{
  background(0);
  noStroke();

  //---------- CITANJE PODATAKA ------------

  if (myPort.available()>0)
  {
    String data = myPort.readString();
    String data1;

    data1 = data.replaceFirst(";", ",0");

    String[] list = split(data1, ',');

    //Processing lose parsuje string zato se ; menja sa ,0 pa ima 7 vrednosti!
    if (list.length==7)
    {
      acc[0] = Float.parseFloat(list[0]);  //Accelerometer X
      acc[1] = Float.parseFloat(list[1]);  //Accelerometer Y
      acc[2] = Float.parseFloat(list[2]);  //Accelerometer Z
      
      gyro[0] = Float.parseFloat(list[3]); //Ziroskop      X
      gyro[1] = Float.parseFloat(list[4]); //Ziroskop      Y
      gyro[2] = Float.parseFloat(list[5]); //Ziroskop      Z

      if(rezim)
      {
        rezimRada="Akcelerometar";
        accelerometerAngle();
      }
      else
      {
        rezimRada="Akcelerometar+Ziroskop";
        complementaryAngle();
      }
    }
  }

  //----------------------------------------------------

  //Iscrtavanje kocke
  TexturedCube(-ugaoX_rad, ugaoY_rad);

  //Iscrtavanje teksta
  text("9DOF IMU kontrola kocke",width-200,25);
  text("By: A.Zdravkovic",width-170,50);
  text("Rezim: " +rezimRada , 10, height-60);
  text("Ugao X: "+ugaoX_last+" °", 10, height-40);
  text("Ugao Y: "+ugaoY_last+" °", 10, height-20);
}

void controlEvent(ControlEvent e)
{
  if (e.isFrom(cp5.getController("trangle_slider")))
  {
    tresh_angle = e.getController().getValue();
  }
  
  if(e.isFrom(cp5.getController("mixture_slider")))
  {
     mesavina = e.getController().getValue(); 
     mixtureSlider.setLabel("Ziroskop: "+round(mesavina*100)+"%\n"+"Akcelerometar: "+round((1.0-mesavina)*100)+" %");
  }
  
  if (e.isFrom(cp5.getController("toggle_rezim")))
  {
     float val = e.getController().getValue();
     
     if(val==1.0)
     {
       rezim=true;
     }
     else
     {
       rezim=false;
     }
  }
}


/* Izracunavanje na osnovu accelerometr-a */
void accelerometerAngle()
{
  rezimRada="Akcelerometar";
  treshSlider.show();
  mixtureSlider.hide();
  
  //ugaoX = atan(acc[0]/sqrt(acc[1]*acc[1]+acc[2]*acc[2]))*100;
  //ugaoY = atan(acc[1]/sqrt(acc[0]*acc[0]+acc[2]*acc[2]))*100;
  
  ugaoX = atan2(acc[0],acc[2]) * 180 / M_PI;
  ugaoY = atan2(acc[1],acc[2]) * 180 / M_PI;

  ugaoX = round(ugaoX);
  ugaoY = round(ugaoY);
  
  ugaoZ=0;

  /* KOD ZA 360 */
  /*
  if(acc[2] < 0) //Z accelerometr-a < 0 
   {
   if(ugaoX < 0)
   {
   ugaoX = -180-ugaoX;
   }
   else
   {
   ugaoX = 180-ugaoX;
   }
   if(ugaoY < 0)
   {
   ugaoY = -180-ugaoY;
   }else
   {
   ugaoY = 180-ugaoY;
   }
   }
   */

  if (ugaoY>=ugaoY_last+tresh_angle || ugaoY<=ugaoY_last-tresh_angle)
  {
    ugaoY_last = ugaoY; 

    if (ugaoY_last <= tresh_zero && ugaoY_last >= -tresh_zero)
    {
      ugaoY_last=0.0;
    }
  }

  if (ugaoX>=ugaoX_last+tresh_angle || ugaoX<=ugaoX_last-tresh_angle)
  {
    ugaoX_last = ugaoX; 

    if (ugaoX_last <= tresh_zero && ugaoX_last>= -tresh_zero)
    {
      ugaoX_last=0.0;
    }
  }
  
  ugaoX_rad = (ugaoX_last)*PI/180;
  ugaoY_rad = (ugaoY_last)*PI/180; 

  //println("X: "+ugaoX_last+" Y: "+ugaoY_last);
}

/* Komplementarni filtar */
void complementaryAngle()
{
    treshSlider.hide();
    mixtureSlider.show();
    rezimRada="Ziroskop + Akcelerometar";
 
    float dt=0.06;
    
    // Integraljenje ziroskopa
    ugaoY_last += ((float)gyro[0] / gyro_sensitivity) * dt; 
    ugaoX_last -= ((float)gyro[1] / gyro_sensitivity) * dt; 

    ugaoY = atan2(acc[1],acc[2]) * 180 / M_PI;        //UgaoY - Accelerometar Y
    ugaoY_last = ugaoY_last * mesavina + (1.0-mesavina)*ugaoY;  
 
    ugaoX = atan2(acc[0], acc[2]) * 180 / M_PI;
    ugaoX_last = ugaoX_last * mesavina + (1.0-mesavina)*ugaoX;
    
    ugaoX_last = round(ugaoX_last);
    ugaoY_last = round(ugaoY_last);
    
    ugaoX_rad = (ugaoX_last)*PI/180;
    ugaoY_rad = (ugaoY_last)*PI/180; 
   
    //println("Pitch: "+ugaoX_last+" Roll: "+ugaoY_last);
}
-- === Iseras Mental Health App Database ===

DROP DATABASE IF EXISTS iseras_db;
CREATE DATABASE iseras_db;
USE iseras_db;

-- Users Table
CREATE TABLE Users (
    user_id INT AUTO_INCREMENT PRIMARY KEY,
    full_name VARCHAR(100) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    user_type ENUM('Patient', 'Therapist') NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Therapist Profile
CREATE TABLE TherapistProfiles (
    therapist_id INT PRIMARY KEY,
    specialization VARCHAR(100),
    license_number VARCHAR(50) UNIQUE,
    years_experience INT,
    FOREIGN KEY (therapist_id) REFERENCES Users(user_id)
);

-- Appointments
CREATE TABLE Appointments (
    appointment_id INT AUTO_INCREMENT PRIMARY KEY,
    patient_id INT NOT NULL,
    therapist_id INT NOT NULL,
    appointment_date DATETIME NOT NULL,
    status ENUM('Scheduled', 'Completed', 'Cancelled') DEFAULT 'Scheduled',
    notes TEXT,
    FOREIGN KEY (patient_id) REFERENCES Users(user_id),
    FOREIGN KEY (therapist_id) REFERENCES Users(user_id)
);

-- Mental Health Logs
CREATE TABLE HealthLogs (
    log_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    entry_date DATE NOT NULL,
    mood ENUM('Happy', 'Sad', 'Anxious', 'Calm', 'Angry', 'Neutral') NOT NULL,
    journal TEXT,
    FOREIGN KEY (user_id) REFERENCES Users(user_id)
);

-- Assessments (Quiz Definitions)
CREATE TABLE Assessments (
    assessment_id INT AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(100) NOT NULL,
    description TEXT
);

-- Questions per Assessment
CREATE TABLE AssessmentQuestions (
    question_id INT AUTO_INCREMENT PRIMARY KEY,
    assessment_id INT NOT NULL,
    question_text TEXT NOT NULL,
    FOREIGN KEY (assessment_id) REFERENCES Assessments(assessment_id)
);

-- User Responses to Assessments
CREATE TABLE AssessmentResponses (
    response_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    question_id INT NOT NULL,
    response TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES Users(user_id),
    FOREIGN KEY (question_id) REFERENCES AssessmentQuestions(question_id)
);

-- Resources (Articles, Audio, Videos)
CREATE TABLE Resources (
    resource_id INT AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(100),
    type ENUM('Article', 'Audio', 'Video'),
    url VARCHAR(255),
    description TEXT
);

-- User-Resource (View/Download Tracking)
CREATE TABLE UserResources (
    user_id INT NOT NULL,
    resource_id INT NOT NULL,
    accessed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id, resource_id),
    FOREIGN KEY (user_id) REFERENCES Users(user_id),
    FOREIGN KEY (resource_id) REFERENCES Resources(resource_id)
);

-- Messaging System
CREATE TABLE Messages (
    message_id INT AUTO_INCREMENT PRIMARY KEY,
    sender_id INT NOT NULL,
    receiver_id INT NOT NULL,
    message TEXT NOT NULL,
    sent_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (sender_id) REFERENCES Users(user_id),
    FOREIGN KEY (receiver_id) REFERENCES Users(user_id)
);

-- Sample Data
INSERT INTO Users (full_name, email, password_hash, user_type) VALUES
('John Doe', 'john@example.com', 'hashed_pw1', 'Patient'),
('Dr. Emily Smith', 'emily@example.com', 'hashed_pw2', 'Therapist');

INSERT INTO TherapistProfiles (therapist_id, specialization, license_number, years_experience) VALUES
(2, 'Cognitive Behavioral Therapy', 'LIC12345', 7);

INSERT INTO Appointments (patient_id, therapist_id, appointment_date, status, notes) VALUES
(1, 2, '2025-05-04 10:00:00', 'Scheduled', 'Initial consultation');

INSERT INTO HealthLogs (user_id, entry_date, mood, journal) VALUES
(1, '2025-05-01', 'Anxious', 'Feeling overwhelmed with work.'),
(1, '2025-05-02', 'Calm', 'Practiced breathing exercises.');

INSERT INTO Assessments (title, description) VALUES
('Stress Level Test', 'Evaluate current stress levels');

INSERT INTO AssessmentQuestions (assessment_id, question_text) VALUES
(1, 'How often do you feel overwhelmed?'),
(1, 'Do you experience sleep disturbances?');

INSERT INTO AssessmentResponses (user_id, question_id, response) VALUES
(1, 1, 'Often'),
(1, 2, 'Sometimes');

INSERT INTO Resources (title, type, url, description) VALUES
('Guided Meditation for Stress', 'Audio', 'https://iseras.com/audio/meditation1', '10-minute guided session.'),
('Understanding Anxiety', 'Article', 'https://iseras.com/article/anxiety', 'Comprehensive article on managing anxiety.');

INSERT INTO UserResources (user_id, resource_id) VALUES
(1, 1),
(1, 2);

INSERT INTO Messages (sender_id, receiver_id, message) VALUES
(1, 2, 'Hi Dr. Smith, I’m feeling anxious lately. Can we reschedule?'),
(2, 1, 'Sure John, let’s find a time that works.');

-- Indexes
CREATE INDEX idx_appointments_patient_id ON Appointments(patient_id);
CREATE INDEX idx_appointments_therapist_id ON Appointments(therapist_id);
CREATE INDEX idx_appointments_date ON Appointments(appointment_date);
CREATE INDEX idx_healthlogs_user_id ON HealthLogs(user_id);
CREATE INDEX idx_healthlogs_entry_date ON HealthLogs(entry_date);
CREATE INDEX idx_messages_receiver_id ON Messages(receiver_id);
CREATE INDEX idx_messages_sender_id ON Messages(sender_id);
CREATE INDEX idx_userresources_user_id ON UserResources(user_id);

-- Views
CREATE VIEW MoodTrendView AS
SELECT 
    user_id,
    entry_date,
    mood
FROM HealthLogs
ORDER BY user_id, entry_date;

CREATE VIEW TherapistAppointmentsSummary AS
SELECT 
    therapist_id,
    COUNT(*) AS total_appointments,
    SUM(CASE WHEN status = 'Completed' THEN 1 ELSE 0 END) AS completed_appointments
FROM Appointments
GROUP BY therapist_id;

-- Stored Procedures
DELIMITER //

CREATE PROCEDURE GetWeeklyMoodSummary(IN uid INT)
BEGIN
    SELECT 
        WEEK(entry_date) AS week_number,
        mood,
        COUNT(*) AS mood_count
    FROM HealthLogs
    WHERE user_id = uid
    GROUP BY week_number, mood
    ORDER BY week_number;
END //

CREATE PROCEDURE GetTherapistActivity(IN tid INT)
BEGIN
    SELECT 
        a.appointment_date,
        u.full_name AS patient_name,
        a.status,
        a.notes
    FROM Appointments a
    JOIN Users u ON a.patient_id = u.user_id
    WHERE a.therapist_id = tid
    ORDER BY a.appointment_date DESC;
END //

DELIMITER ;

-- Audit Log Table
CREATE TABLE AuditLog (
    audit_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    action VARCHAR(100) NOT NULL,
    table_name VARCHAR(50) NOT NULL,
    record_id INT NOT NULL,
    old_value TEXT,
    new_value TEXT,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES Users(user_id)
);

-- Trigger: Log Appointment Status Changes
DELIMITER //

CREATE TRIGGER trg_appointment_update
AFTER UPDATE ON Appointments
FOR EACH ROW
BEGIN
    IF OLD.status <> NEW.status THEN
        INSERT INTO AuditLog (user_id, action, table_name, record_id, old_value, new_value)
        VALUES (NEW.patient_id, 'Update Appointment Status', 'Appointments', NEW.appointment_id, OLD.status, NEW.status);
    END IF;
END //

DELIMITER ;

-- MySQL dump 10.13  Distrib 8.0.44, for Win64 (x86_64)
--
-- Host: 127.0.0.1    Database: knowledge_base_db
-- ------------------------------------------------------
-- Server version	8.0.44

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!50503 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `comments`
--

DROP TABLE IF EXISTS `comments`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `comments` (
  `comment_id` int NOT NULL AUTO_INCREMENT,
  `task_id` int NOT NULL,
  `author_user_id` int NOT NULL,
  `text` text COLLATE utf8mb4_unicode_ci NOT NULL,
  `created_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`comment_id`),
  KEY `fk_comments_author` (`author_user_id`),
  KEY `idx_comments_task` (`task_id`),
  CONSTRAINT `fk_comments_author` FOREIGN KEY (`author_user_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_comments_task` FOREIGN KEY (`task_id`) REFERENCES `tasks` (`task_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `comments`
--

LOCK TABLES `comments` WRITE;
/*!40000 ALTER TABLE `comments` DISABLE KEYS */;
INSERT INTO `comments` VALUES (1,1,2,'Предлагаю добавить раздел про версионирование API.','2026-10-06 09:19:28');
/*!40000 ALTER TABLE `comments` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `invitation_statuses`
--

DROP TABLE IF EXISTS `invitation_statuses`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `invitation_statuses` (
  `invitation_status_id` int NOT NULL AUTO_INCREMENT,
  `name` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  PRIMARY KEY (`invitation_status_id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `invitation_statuses`
--

LOCK TABLES `invitation_statuses` WRITE;
/*!40000 ALTER TABLE `invitation_statuses` DISABLE KEYS */;
INSERT INTO `invitation_statuses` VALUES (1,'активен'),(2,'использован'),(3,'отозван');
/*!40000 ALTER TABLE `invitation_statuses` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `invitations`
--

DROP TABLE IF EXISTS `invitations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `invitations` (
  `invitation_id` int NOT NULL AUTO_INCREMENT,
  `invite_code` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `team_id` int NOT NULL,
  `creator_user_id` int NOT NULL,
  `created_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `expires_time` datetime NOT NULL,
  `invitation_status_id` int NOT NULL,
  PRIMARY KEY (`invitation_id`),
  UNIQUE KEY `invite_code` (`invite_code`),
  KEY `fk_inv_creator` (`creator_user_id`),
  KEY `fk_inv_status` (`invitation_status_id`),
  KEY `idx_invitations_code` (`invite_code`),
  KEY `idx_invitations_team` (`team_id`),
  CONSTRAINT `fk_inv_creator` FOREIGN KEY (`creator_user_id`) REFERENCES `users` (`user_id`) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `fk_inv_status` FOREIGN KEY (`invitation_status_id`) REFERENCES `invitation_statuses` (`invitation_status_id`) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `fk_inv_team` FOREIGN KEY (`team_id`) REFERENCES `teams` (`team_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `invitations`
--

LOCK TABLES `invitations` WRITE;
/*!40000 ALTER TABLE `invitations` DISABLE KEYS */;
INSERT INTO `invitations` VALUES (1,'INV-2024-XYZ-001',1,1,'2026-10-06 09:19:28','2026-10-13 09:19:28',1);
/*!40000 ALTER TABLE `invitations` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `notification_read_statuses`
--

DROP TABLE IF EXISTS `notification_read_statuses`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `notification_read_statuses` (
  `read_status_id` int NOT NULL AUTO_INCREMENT,
  `name` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  PRIMARY KEY (`read_status_id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `notification_read_statuses`
--

LOCK TABLES `notification_read_statuses` WRITE;
/*!40000 ALTER TABLE `notification_read_statuses` DISABLE KEYS */;
INSERT INTO `notification_read_statuses` VALUES (1,'не прочитано'),(2,'прочитано');
/*!40000 ALTER TABLE `notification_read_statuses` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `notifications`
--

DROP TABLE IF EXISTS `notifications`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `notifications` (
  `notification_id` int NOT NULL AUTO_INCREMENT,
  `recipient_user_id` int NOT NULL,
  `task_id` int DEFAULT NULL,
  `text` text COLLATE utf8mb4_unicode_ci NOT NULL,
  `sent_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `read_status_id` int NOT NULL,
  PRIMARY KEY (`notification_id`),
  KEY `fk_notif_task` (`task_id`),
  KEY `fk_notif_status` (`read_status_id`),
  KEY `idx_notifications_recipient` (`recipient_user_id`),
  CONSTRAINT `fk_notif_recipient` FOREIGN KEY (`recipient_user_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_notif_status` FOREIGN KEY (`read_status_id`) REFERENCES `notification_read_statuses` (`read_status_id`) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `fk_notif_task` FOREIGN KEY (`task_id`) REFERENCES `tasks` (`task_id`) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `notifications`
--

LOCK TABLES `notifications` WRITE;
/*!40000 ALTER TABLE `notifications` DISABLE KEYS */;
INSERT INTO `notifications` VALUES (1,1,1,'Новый комментарий к задаче \"Требования к API\"','2026-10-06 09:19:28',1);
/*!40000 ALTER TABLE `notifications` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `presence_statuses`
--

DROP TABLE IF EXISTS `presence_statuses`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `presence_statuses` (
  `presence_status_id` int NOT NULL AUTO_INCREMENT,
  `name` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  PRIMARY KEY (`presence_status_id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `presence_statuses`
--

LOCK TABLES `presence_statuses` WRITE;
/*!40000 ALTER TABLE `presence_statuses` DISABLE KEYS */;
INSERT INTO `presence_statuses` VALUES (1,'на месте'),(3,'не беспокоить'),(2,'отошел');
/*!40000 ALTER TABLE `presence_statuses` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `remark_statuses`
--

DROP TABLE IF EXISTS `remark_statuses`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `remark_statuses` (
  `remark_status_id` int NOT NULL AUTO_INCREMENT,
  `name` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  PRIMARY KEY (`remark_status_id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `remark_statuses`
--

LOCK TABLES `remark_statuses` WRITE;
/*!40000 ALTER TABLE `remark_statuses` DISABLE KEYS */;
INSERT INTO `remark_statuses` VALUES (1,'открыто'),(2,'устранено');
/*!40000 ALTER TABLE `remark_statuses` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `remarks`
--

DROP TABLE IF EXISTS `remarks`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `remarks` (
  `remark_id` int NOT NULL AUTO_INCREMENT,
  `task_id` int NOT NULL,
  `change_id` int DEFAULT NULL,
  `author_user_id` int NOT NULL,
  `fragment_identifier` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `text` text COLLATE utf8mb4_unicode_ci NOT NULL,
  `sent_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `remark_status_id` int NOT NULL,
  PRIMARY KEY (`remark_id`),
  KEY `fk_remarks_change` (`change_id`),
  KEY `fk_remarks_author` (`author_user_id`),
  KEY `fk_remarks_status` (`remark_status_id`),
  KEY `idx_remarks_task` (`task_id`),
  CONSTRAINT `fk_remarks_author` FOREIGN KEY (`author_user_id`) REFERENCES `users` (`user_id`) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `fk_remarks_change` FOREIGN KEY (`change_id`) REFERENCES `task_changes` (`change_id`) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT `fk_remarks_status` FOREIGN KEY (`remark_status_id`) REFERENCES `remark_statuses` (`remark_status_id`) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `fk_remarks_task` FOREIGN KEY (`task_id`) REFERENCES `tasks` (`task_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `remarks`
--

LOCK TABLES `remarks` WRITE;
/*!40000 ALTER TABLE `remarks` DISABLE KEYS */;
/*!40000 ALTER TABLE `remarks` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `support_requests`
--

DROP TABLE IF EXISTS `support_requests`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `support_requests` (
  `request_id` int NOT NULL AUTO_INCREMENT,
  `user_id` int NOT NULL,
  `subject` varchar(500) COLLATE utf8mb4_unicode_ci NOT NULL,
  `text` text COLLATE utf8mb4_unicode_ci NOT NULL,
  `created_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `processed_time` datetime DEFAULT NULL,
  `processed_by_user_id` int DEFAULT NULL,
  PRIMARY KEY (`request_id`),
  KEY `fk_sr_user` (`user_id`),
  KEY `fk_sr_processor` (`processed_by_user_id`),
  CONSTRAINT `fk_sr_processor` FOREIGN KEY (`processed_by_user_id`) REFERENCES `users` (`user_id`) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT `fk_sr_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `support_requests`
--

LOCK TABLES `support_requests` WRITE;
/*!40000 ALTER TABLE `support_requests` DISABLE KEYS */;
/*!40000 ALTER TABLE `support_requests` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `system_logs`
--

DROP TABLE IF EXISTS `system_logs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `system_logs` (
  `log_id` int NOT NULL AUTO_INCREMENT,
  `log_type` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `message` text COLLATE utf8mb4_unicode_ci NOT NULL,
  `created_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `user_id` int DEFAULT NULL,
  `task_id` int DEFAULT NULL,
  PRIMARY KEY (`log_id`),
  KEY `fk_logs_user` (`user_id`),
  KEY `fk_logs_task` (`task_id`),
  KEY `idx_logs_type` (`log_type`),
  CONSTRAINT `fk_logs_task` FOREIGN KEY (`task_id`) REFERENCES `tasks` (`task_id`) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT `fk_logs_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `system_logs`
--

LOCK TABLES `system_logs` WRITE;
/*!40000 ALTER TABLE `system_logs` DISABLE KEYS */;
/*!40000 ALTER TABLE `system_logs` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `task_changes`
--

DROP TABLE IF EXISTS `task_changes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `task_changes` (
  `change_id` int NOT NULL AUTO_INCREMENT,
  `task_id` int NOT NULL,
  `author_user_id` int NOT NULL,
  `author_role_id` int NOT NULL,
  `change_date` date NOT NULL,
  `change_time` time NOT NULL,
  `diff_content` longtext COLLATE utf8mb4_unicode_ci,
  PRIMARY KEY (`change_id`),
  KEY `fk_changes_author` (`author_user_id`),
  KEY `fk_changes_role` (`author_role_id`),
  KEY `idx_changes_task` (`task_id`),
  CONSTRAINT `fk_changes_author` FOREIGN KEY (`author_user_id`) REFERENCES `users` (`user_id`) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `fk_changes_role` FOREIGN KEY (`author_role_id`) REFERENCES `team_roles` (`team_role_id`) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `fk_changes_task` FOREIGN KEY (`task_id`) REFERENCES `tasks` (`task_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `task_changes`
--

LOCK TABLES `task_changes` WRITE;
/*!40000 ALTER TABLE `task_changes` DISABLE KEYS */;
/*!40000 ALTER TABLE `task_changes` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `task_statuses`
--

DROP TABLE IF EXISTS `task_statuses`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `task_statuses` (
  `task_status_id` int NOT NULL AUTO_INCREMENT,
  `name` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  PRIMARY KEY (`task_status_id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `task_statuses`
--

LOCK TABLES `task_statuses` WRITE;
/*!40000 ALTER TABLE `task_statuses` DISABLE KEYS */;
INSERT INTO `task_statuses` VALUES (2,'в работе'),(4,'завершена'),(3,'на доработке'),(1,'свободна');
/*!40000 ALTER TABLE `task_statuses` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `tasks`
--

DROP TABLE IF EXISTS `tasks`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `tasks` (
  `task_id` int NOT NULL AUTO_INCREMENT,
  `team_id` int NOT NULL,
  `title` varchar(500) COLLATE utf8mb4_unicode_ci NOT NULL,
  `content` longtext COLLATE utf8mb4_unicode_ci,
  `task_status_id` int NOT NULL,
  `assignee_user_id` int DEFAULT NULL,
  `created_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `last_modified_at` datetime DEFAULT NULL,
  `is_archived` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`task_id`),
  KEY `idx_tasks_team` (`team_id`),
  KEY `idx_tasks_status` (`task_status_id`),
  KEY `idx_tasks_assignee` (`assignee_user_id`),
  CONSTRAINT `fk_tasks_assignee` FOREIGN KEY (`assignee_user_id`) REFERENCES `users` (`user_id`) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT `fk_tasks_status` FOREIGN KEY (`task_status_id`) REFERENCES `task_statuses` (`task_status_id`) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `fk_tasks_team` FOREIGN KEY (`team_id`) REFERENCES `teams` (`team_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `tasks`
--

LOCK TABLES `tasks` WRITE;
/*!40000 ALTER TABLE `tasks` DISABLE KEYS */;
INSERT INTO `tasks` VALUES (1,1,'Документ: Требования к API','# Требования к API\n\n- REST\n- JSON\n- Авторизация JWT',1,NULL,'2026-10-06 09:19:28',NULL,0);
/*!40000 ALTER TABLE `tasks` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `team_members`
--

DROP TABLE IF EXISTS `team_members`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `team_members` (
  `team_member_id` int NOT NULL AUTO_INCREMENT,
  `team_id` int NOT NULL,
  `user_id` int NOT NULL,
  `team_role_id` int NOT NULL,
  `joined_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`team_member_id`),
  UNIQUE KEY `uq_team_member` (`team_id`,`user_id`),
  KEY `fk_tm_role` (`team_role_id`),
  KEY `idx_team_members_user` (`user_id`),
  KEY `idx_team_members_team` (`team_id`),
  CONSTRAINT `fk_tm_role` FOREIGN KEY (`team_role_id`) REFERENCES `team_roles` (`team_role_id`) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `fk_tm_team` FOREIGN KEY (`team_id`) REFERENCES `teams` (`team_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_tm_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `team_members`
--

LOCK TABLES `team_members` WRITE;
/*!40000 ALTER TABLE `team_members` DISABLE KEYS */;
INSERT INTO `team_members` VALUES (1,1,1,1,'2026-10-06 09:19:28'),(2,1,2,2,'2026-10-06 09:19:28'),(3,1,3,2,'2026-10-06 09:19:28'),(4,1,4,3,'2026-10-06 09:19:28');
/*!40000 ALTER TABLE `team_members` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `team_roles`
--

DROP TABLE IF EXISTS `team_roles`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `team_roles` (
  `team_role_id` int NOT NULL AUTO_INCREMENT,
  `name` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  PRIMARY KEY (`team_role_id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `team_roles`
--

LOCK TABLES `team_roles` WRITE;
/*!40000 ALTER TABLE `team_roles` DISABLE KEYS */;
INSERT INTO `team_roles` VALUES (1,'владелец команды'),(3,'гость'),(2,'участник');
/*!40000 ALTER TABLE `team_roles` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `teams`
--

DROP TABLE IF EXISTS `teams`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `teams` (
  `team_id` int NOT NULL AUTO_INCREMENT,
  `name` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `description` text COLLATE utf8mb4_unicode_ci,
  `created_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `creator_user_id` int NOT NULL,
  PRIMARY KEY (`team_id`),
  KEY `fk_teams_creator` (`creator_user_id`),
  CONSTRAINT `fk_teams_creator` FOREIGN KEY (`creator_user_id`) REFERENCES `users` (`user_id`) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `teams`
--

LOCK TABLES `teams` WRITE;
/*!40000 ALTER TABLE `teams` DISABLE KEYS */;
INSERT INTO `teams` VALUES (1,'Разработка проекта X','Основная команда разработки','2026-10-06 09:19:28',1);
/*!40000 ALTER TABLE `teams` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `user_activity_statuses`
--

DROP TABLE IF EXISTS `user_activity_statuses`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `user_activity_statuses` (
  `activity_status_id` int NOT NULL AUTO_INCREMENT,
  `name` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  PRIMARY KEY (`activity_status_id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `user_activity_statuses`
--

LOCK TABLES `user_activity_statuses` WRITE;
/*!40000 ALTER TABLE `user_activity_statuses` DISABLE KEYS */;
INSERT INTO `user_activity_statuses` VALUES (1,'активен'),(2,'заблокирован');
/*!40000 ALTER TABLE `user_activity_statuses` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `users`
--

DROP TABLE IF EXISTS `users`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `users` (
  `user_id` int NOT NULL AUTO_INCREMENT,
  `nickname` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `email` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `password_hash` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `avatar_url` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `presence_status_id` int NOT NULL,
  `activity_status_id` int NOT NULL,
  `registration_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`user_id`),
  UNIQUE KEY `nickname` (`nickname`),
  UNIQUE KEY `email` (`email`),
  KEY `fk_users_presence` (`presence_status_id`),
  KEY `fk_users_activity` (`activity_status_id`),
  KEY `idx_users_email` (`email`),
  KEY `idx_users_nickname` (`nickname`),
  CONSTRAINT `fk_users_activity` FOREIGN KEY (`activity_status_id`) REFERENCES `user_activity_statuses` (`activity_status_id`) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `fk_users_presence` FOREIGN KEY (`presence_status_id`) REFERENCES `presence_statuses` (`presence_status_id`) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `users`
--

LOCK TABLES `users` WRITE;
/*!40000 ALTER TABLE `users` DISABLE KEYS */;
INSERT INTO `users` VALUES (1,'admin','admin@example.com','240be518fabd2724ddb6f04eeb1da5967448d7e831c08c8fa822809f74c720a9',NULL,1,1,'2026-10-06 09:19:28'),(2,'ivan_petrov','ivan@example.com','6c84b1086e558a0b9dad7623979f6ddf9f337084f281d9b3a07273d04b425344',NULL,1,1,'2026-10-06 09:19:28'),(3,'maria_s','maria@example.com','626e3c805e77eeb472c42c6be607be2af7ac5c08fd7050f278e0330fe81abf57',NULL,2,1,'2026-10-06 09:19:28'),(4,'guest_user','guest@example.com','6b93ccba414ac1d0ae1e77f3fac560c748a6701ed6946735a49d463351518e16',NULL,3,1,'2026-10-06 09:19:28');
/*!40000 ALTER TABLE `users` ENABLE KEYS */;
UNLOCK TABLES;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2026-10-13 11:45:40
